;; needs "/Applications/SQLAnywhere12/System/lib32"
;;  added to DYLD_LIBRARY_PATH so it can find libdbjdbc12.jnilib and dependencies.
;; for now add (setenv "DYLD_LIBRARY_PATH" (concatenate 'string (getenv "DYLD_LIBRARY_PATH") 
;; ":/Applications/SQLAnywhere12/System/lib32")) to your .emacs
;; (#"load" 'System "/Applications/SQLAnywhere12/System/lib32/libdbjdbc12.jnilib")  
;; fails there is no easy way to update DYLD_LIBRARY_PATH within a running java instance. POS.
(defparameter *results-ht* nil)

;; the global variables are used to generate unique iri's
(defparameter *iri* nil)
(defparameter *iri-count* nil)
y
;; for ease of use, set up some aliases to reference ohd classes
(def-uri-alias "fma_tooth" !obo:FMA_12516)
(def-uri-alias "dental_patient" !obo:OHD_0000012)
(def-uri-alias "patient_role" !obo:OBI_0000093)
(def-uri-alias "dental_finding" !obo:OHD_0000010)
(def-uri-alias "caries_finding" !obo:OHD_0000024)
(def-uri-alias "fractured_tooth_finding" !obo:OHD_0000030)
(def-uri-alias "missing_tooth_finding" !obo:OHD_0000026)
(def-uri-alias "dentition" !obo:OHD_0000027)
(def-uri-alias "caries" !obo:OHD_0000021)
(def-uri-alias "fractured_tooth" !obo:OHD_0000029)
(def-uri-alias "restoration_material" !obo:OHD_0000000)
(def-uri-alias "amalgam" !obo:OHD_0000001)
(def-uri-alias "gold" !obo:OHD_0000034)
(def-uri-alias "porcelain" !obo:OHD_0000035)
(def-uri-alias "resin" !obo:OHD_0000036)
(def-uri-alias "dental_exam" !obo:OHD_0000019)
(def-uri-alias "hard_tissue_exam" !obo:OHD_0000025)
(def-uri-alias "soft_tissue_exam" !obo:OHD_0000032)
(def-uri-alias "dental_visit" !obo:OHD_0000009)
(def-uri-alias "performing_a_dental_clinical_assement" !obo:OHD_0000011)
(def-uri-alias "procedure" !obo:OHD_0000002)
(def-uri-alias "endodontic_procedure" !obo:OHD_0000003)
(def-uri-alias "restorative_procedure" !obo:OHD_0000004)
(def-uri-alias "crown_restoration" !obo:OHD_0000033)
(def-uri-alias "filling_restoration" !obo:OHD_0000006)
(def-uri-alias "direct_restoration" !obo:OHD_0000037)
(def-uri-alias "amalgam_filling_restoration" !obo:OHD_0000041)
(def-uri-alias "resin_filling_restoration" !obo:OHD_0000042)
(def-uri-alias "indirect_restoration" !obo:OHD_0000038)
(def-uri-alias "gold_filling_restoration" !obo:OHD_0000039)
(def-uri-alias "procelain_filling_restoration" !obo:OHD_0000040)
(def-uri-alias "surgical_dental_procedure" !obo:OHD_0000044)
(def-uri-alias "surgical_procedure" !obo:OHD_0000005)
(def-uri-alias "tooth_to_be_restored_role" !obo:OHD_0000007)
(def-uri-alias "tooth_to_be_filled_role" !obo:OHD_0000008)
(def-uri-alias "has_participant" !obo:BFO_0000057)
(def-uri-alias "has_role" !obo:BFO_0000087)
(def-uri-alias "has_part" !<http://www.obofoundry.org/ro/ro.owl#has_part>)
(def-uri-alias "has_specified_output" !obi:OBI_0000299)
(def-uri-alias "inheres_in" !obo:BFO_0000052)
(def-uri-alias "is_about" !obo:IAO_0000136)
(def-uri-alias "is_part_of" !obo:BFO_0000050)
(def-uri-alias "realizes" !obo:BFO_0000055)
(def-uri-alias "occurrence_date" !obo:OHD_0000015)
(def-uri-alias "patient_ID" !obo:OHD_0000014)

(add-to-classpath "/Applications/SQLAnywhere12/System/java/sajdbc4.jar")

(defun get-filling-ont (&key iri ont-iri patient-id file-name print-results)
  (let ((connection nil)
	(statement nil)
	(results nil)
	(query nil)
	(url nil)
	(count 0))
    
    ;; set default base and ontology iri's 
    (when (null iri) (setf iri "http://purl.obolibrary.org/obo/individuals/"))
    (when (null ont-iri) (setf ont-iri "http://purl.obolibrary.org/obo/fillings.owl"))
    
    ;; set global variables 
    (setf *iri* iri)
    (setf *iri-count* 1)
    
    ;; set up connection string and query
    (setf url"jdbc:sqlanywhere:Server=PattersonPM;UserID=PDBA;password=4561676C65536F6674")
    (setf query (get-amalgam-query))

    (with-ontology ont (:collecting t :base iri :ontology-iri ont-iri)
	((unwind-protect
	      (progn
		;; connect to db and get data
		(setf connection (#"getConnection" 'java.sql.DriverManager url))
		(setf statement (#"createStatement" connection))
		(setf results (#"executeQuery" statement query))
	   	
		;; import the ohd ontology
		(as `(imports (make-uri "http://purl.obolibrary.org/obo/ohd/dev/ohd.owl")))

		;; declare data properties
		(as `(declaration (data-property !occurrence_date)))
		(as `(declaration (data-property !patient_ID)))
		    
		(loop while (#"next" results) do
		     (as (get-amalgam-axioms 
			  (#"getString" results "patient_id")
			  (#"getString" results "tran_date")
			  (#"getString" results "description")
			  (#"getString" results "tooth_data")
			  (#"getString" results "surface")
			  (#"getString" results "ada_code")
			  (#"getString" results "ada_code_description")))
		     (incf count)))
	   
	   ;; database cleanup
	   (and connection (#"close" connection))
	   (and results (#"close" results))
	   (and statement (#"close" statement))))

      ;; return the ontology
      ont)))

(defun get-amalgam-axioms (patient-id tran-date description 
			   tooth-data surface ada-code ada-code-description)
  (let ((axioms nil)
	(patient-uri nil)
	(patient-role-uri nil)
	(tooth-uri nil)
	(tooth-role-uri nil)
	(amalgam-uri nil)
	(amalgam-retoration-uri nil)
	(tooth-string nil)
	(teeth-list nil))
	
    ;; get axioms abou the patient
    ;;(push (get-patient-axioms iri patient-id) axioms) ;; this doesn' work.. why not?
    (setf patient-uri (get-iri))
    (setf patient-role-uri (get-iri))
    (setf axioms (get-patient-axioms patient-uri patient-role-uri patient-id))

    ;; tooth_data
    ;; get list of teeth in tooth_data array
    (setf teeth-list (get-teeth tooth-data))
    (loop for tooth in teeth-list do
         
         ;;;;  declare instances of participating entitie ;;;;

         ;; declare tooth instance; for now each tooth will be and instance of !fma:tooth
	 (setf tooth-uri (get-iri))
	 (push `(declaration (named-individual ,tooth-uri)) axioms)
	 (push `(class-assertion !fma_tooth ,tooth-uri) axioms)	     

	 ;; add annotation about tooth
	 (setf tooth-string (format nil "~a" tooth))
	 (push `(annotation-assertion !rdfs:label 
				      ,tooth-uri
				      ,(str+ "tooth " tooth-string
					     " of patient " patient-id)) axioms)

         ;; declare instance of !ohd:'tooth to be filled role'
	 (setf tooth-role-uri (get-iri))
	 (push `(declaration (named-individual ,tooth-role-uri)) axioms)
	 (push `(class-assertion !tooth_to_be_filled_role ,tooth-role-uri) axioms)

	 ;; add annotation about 'tooth to be filled role'
	 (push `(annotation-assertion !rdfs:label 
				      ,tooth-role-uri
				      ,(str+ "tooth to be filled role for tooth " 
					     tooth-string " of patient " patient-id)) axioms)

         ;; declare instance of amalgam (!ohd:amalgam) for tooth
	 (setf amalgam-uri (get-iri))
	 (push `(declaration (named-individual ,amalgam-uri)) axioms)
	 (push `(class-assertion !amalgam ,amalgam-uri) axioms)	 
	 
	 ;; add annotation about this instance of amalgam
	 (push `(annotation-assertion !rdfs:label 
				      ,amalgam-uri
				      ,(str+ "amalgam placed in tooth " tooth-string
					     " of patient " patient-id)) axioms)

         ;; declare instance of amalgam restoration (!ohd:'amalgam filling restoration')
	 (setf amalgam-retoration-uri (get-iri))
	 (push `(declaration (named-individual ,amalgam-retoration-uri)) axioms)
	 (push `(class-assertion !amalgam_filling_restoration ,amalgam-retoration-uri) axioms)

	 ;; add annotation about this amalgam restoration procedure
	 (push `(annotation-assertion !rdfs:label 
				      ,amalgam-retoration-uri
				      ,(str+ "amalgam retoration procedure on tooth " 
					     tooth-string " in patient " patient-id)) axioms)

	 ;; add date property !ohd:'occurence date' to 'amalgam filling restoration'
	 ;;(push `(data-property-assertion !occurrence_date
	 ;;				 ,amalgam-retoration-uri ,tran-date) axioms)

	 (push `(data-property-assertion !occurrence_date
					 ,amalgam-retoration-uri 
					 (:literal ,tran-date !xsd:date)) axioms)

	  ;;;; relate instances ;;;;
       
         ;; 'tooth to be filled role' inheres in tooth
	 (push `(object-property-assertion !inheres_in
					   ,tooth-role-uri ,tooth-uri) axioms)

         ;; 'amalgam filling restoration' realizes 'tooth to be filled role'
	 (push `(object-property-assertion !realizes
					   ,amalgam-retoration-uri ,tooth-role-uri) axioms)

         ;; 'amalgam filling restoration' has particpant tooth
	 (push `(object-property-assertion !has_participant
					   ,amalgam-retoration-uri ,tooth-uri) axioms)
	 
      

         ;; 'amalgam filling restoration' has particpant amalgam
	 (push `(object-property-assertion !has_participant 
					   ,amalgam-retoration-uri ,amalgam-uri) axioms)

         ;; 'amalgam filling restoration' has particpant patient
	 (push `(object-property-assertion !has_participant 
					   ,amalgam-retoration-uri ,patient-uri) axioms)
       
	 ) ;; end loop
    
    ;; surface - for now I'll skip this
    ;;(setf uri (make-uri (str+ iri surface)))
	
    ;; description
    ;; for now put the descripton in a label
    ;;(setf uri (get-iri))
	
    ;; ada_code 
    ;;(setf uri (get-iri))

    ;; ada_code_description
    ;;(setf uri (get-iri))
	
    ;; tran_date todo..
    ;;(setf uri (get-iri))
    ;;(data-property-assertion !obo:OHD_0000015 !obo:OHD_0000020 tran-date)

    ;; return axioms
    axioms))
  

(defun get-patient-axioms (patient-uri patient-role-uri patient-id)
  "Returns a list of axioms about a patient that is identified by patient-id."
  (let ((axioms nil))
    ;; create instance/indiviual  patient
    (push `(declaration (named-individual ,patient-uri)) axioms) 

     ;; patient role is an instance of !ohd:'dental patient'
    (push `(class-assertion !dental_patient ,patient-uri) axioms)

    ;; patient role is an instance of !obi:'patient role'
    (push `(class-assertion !patient_role ,patient-role-uri) axioms) 

    ;; 'patient role' inheres in patient
    (push `(object-property-assertion !inheres_in
				      ,patient-role-uri ,patient-uri) axioms)

    ;; add data property 'patient id' to patient
    (push `(data-property-assertion !patient_ID
				    ,patient-uri ,patient-id) axioms)

    ;; add annotation about patient
    (push `(annotation-assertion !rdfs:label 
				 ,patient-uri ,(str+ "dental patient " patient-id)) axioms)

    ;; add annotation about patient role
    (push `(annotation-assertion !rdfs:label 
				 ,patient-role-uri 
				 ,(str+ "'patient role' for patient " patient-id)) axioms)
    
    ;; return axioms
    axioms))

(defun get-teeth (tooth-data)
  "Reads the tooth_data array and returns a list of tooth numbers referenced in the array."
  (let ((teeth-list nil))

    ;; verify that there are at least 32 tooth items in tooth-data
    (when (>= (length tooth-data) 32)
      (loop 
	 for tooth from 0 to 31 do
	   ;; when a postion in tooth-data is marked 'Y' add to teeth list
	   (when (or (equal (char tooth-data tooth) #\Y) 
		     (equal (char tooth-data tooth) #\y))
	     (push (1+ tooth) teeth-list))))

    ;; return list of teeth
    teeth-list))
	   

(defun get-iri ()
  "Returns a unique iri using 'make-uri'."
  (make-uri (get-iri-string)))
  

(defun get-iri-string ()
  "Returns a unique string that is used make a unique iri."
 (let ((iri-string nil))
   ;; build iri; note cdt uri is zero padded length 7: "~7,'0d"
   (setf iri-string (str+ "OHD_" (format nil "~7,'0d" *iri-count*)))
   
   ;; increment iri count
   (incf *iri-count*)

   ;; return new iri string
   (str+ *iri* iri-string)))

(defun get-amalgam-query ()
  (str+ 
   "select top 10 * from patient_history "
   "where ada_code in ('D2140', 'D2150', 'D2160', 'D2161') "
   "and table_name = 'transactions' ")
  )

(defun str+ (&rest values)
  "A shortcut for concatenting a list of strings. Code found at:
http://stackoverflow.com/questions/5457346/lisp-function-to-concatenate-a-list-of-strings
Parameters:
  values:  The string to be concatenated.
Usage:
  (str+ \"string1\"   \"string1\" \"string 3\" ...)
  (str+ s1 s2 s3 ...)"

  ;; the following make use of the format functions
  ;;(format nil "~{~a~}" values)
  ;;; use (format nil "~{~a^ ~}" values) to concatenate with spaces
  ;; this may be the simplist to understant...
  (apply #'concatenate 'string values))