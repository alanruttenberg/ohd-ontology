;;****************************************************************
;; Instructions for being able to connect to Eaglesoft database
;;
;; Ensure that the r21 system file is loaded.
;; For details see comment at top of r21-utilities.lisp

;;****************************************************************
;; Database preparation: 
;; When get-eaglesoft-endodontics-ont is ran, the program verifies that the 
;; action_codes and patient_history tables exist.  This is done by calling 
;; prepare-eaglesoft-db.  However, this only tests that these tables exist in the 
;; user's database. If these table need to be recreated, the call 
;; get-eaglesoft-fillings-ont with :force-create-table key set to t.

(defun get-eaglesoft-endodontics-ont (&key patient-id tooth limit-rows force-create-table)
  "Returns an ontology of the endodontic procedures contained in the Eaglesoft database. The patient-id key creates an ontology based on that specific patient. The tooth key is used to limit results to a specific tooth, and can be used in combination with the patient-id. The limit-rows key restricts the number of records returned from the database.  It is primarily used for testing. The force-create-table key is used to force the program to recreate the actions_codes and patient_history tables."

  (let ((results nil)
	(query nil)
	(occurrence-date nil)
	(count 0))

    ;; verify that the eaglesoft db has the action_codes and patient_history tables
    (prepare-eaglesoft-db :force-create-table force-create-table)

    ;; get query string for restorations
    (setf query (get-eaglesoft-endodontics-query 
		 :patient-id patient-id :tooth tooth :limit-rows limit-rows))

    (with-ontology ont (:collecting t 
			:base *eaglesoft-individual-endodontics-iri-base*
			:ontology-iri *eaglesoft-endodontics-ontology-iri*)
	(;; import needed ontologies
	 (as (get-ohd-import-axioms))

	 ;; get axioms for declaring annotation, object, and data properties used for ohd
	 (as (get-ohd-declaration-axioms))
	 
	 ;; get records from eaglesoft db and create axioms
	 (with-eaglesoft (results query) 
	   (loop while (#"next" results) do
	        ;; determine this occurrence date
		(setf occurrence-date
		      (get-eaglesoft-occurrence-date 
		       (#"getString" results "table_name")
		       (#"getString" results "date_entered")
		       (#"getString" results "date_completed")
		       (#"getString" results "tran_date")))
		     
	        ;; get axioms
		(as (get-eaglesoft-endodontic-axioms 
		     (#"getString" results "patient_id")
		     occurrence-date
		     (#"getString" results "tooth_data")
		     (#"getString" results "ada_code")
		     (#"getString" results "r21_provider_id")
		     (#"getString" results "r21_provider_type")
		     (#"getString" results "row_id")))
		(incf count))))

      ;; return the ontology
      (values ont count))))

(defun get-eaglesoft-endodontic-axioms 
    (patient-id occurrence-date tooth-data ada-code provider-id provider-type record-count)
  (let ((axioms nil)
	(temp-axioms nil) ; used for appending new axioms into the axioms list
	(cdt-class-uri nil)
	(cdt-uri nil)
	(patient-uri nil)
	(endodontic-role-uri nil)
	(endodontic-procedure-uri nil)
	(tooth-name nil)
	(tooth-uri nil)
	(tooth-type-uri nil)
	(teeth-list nil)
	(visit-uri nil))

    ;; tooth_data
    ;; get list of teeth in tooth_data array
    (setf teeth-list (get-eaglesoft-teeth-list tooth-data))

    (loop for tooth in teeth-list do
         ;;;;  declare instances of participating entities ;;;;
	 
	 ;; get uri of patient
	 (setf patient-uri
	       (get-eaglesoft-dental-patient-iri patient-id))
	 
         ;; declare tooth instance; for now each tooth will be and instance of !fma:tooth
	 (setf tooth-name (number-to-fma-tooth tooth :return-tooth-with-number t))
	 (setf tooth-type-uri (number-to-fma-tooth tooth :return-tooth-uri t))
	 (setf tooth-uri (get-eaglesoft-tooth-iri patient-id tooth-type-uri))
	 
	 (push `(declaration (named-individual ,tooth-uri)) axioms)
         ;; note: append puts lists together and doesn't put items in list (like push)
	 (setf temp-axioms (get-ohd-instance-axioms tooth-uri tooth-type-uri))
	 (setf axioms (append temp-axioms axioms))
	 
         ;; add annotation about tooth
	 (push `(annotation-assertion !rdfs:label 
				      ,tooth-uri
				      ,(str+ tooth-name
					     " of patient " patient-id)) axioms)
	 
         ;; declare instance of !ohd:'tooth to undergo endodontic procedure role'
	 (setf endodontic-role-uri
	       (get-eaglesoft-tooth-to-undergo-endodontic-procedure-role-iri
		patient-id tooth record-count))
		
	 (push `(declaration (named-individual ,endodontic-role-uri)) axioms)
	 (setf temp-axioms (get-ohd-instance-axioms endodontic-role-uri 
						    !'tooth to undergo endodontic procedure role'@ohd))
	 (setf axioms (append temp-axioms axioms))

	 ;; add annotation about 'tooth to undergo endodontic procedure role'
	 (push `(annotation-assertion !rdfs:label 
				      ,endodontic-role-uri
				      ,(str+ "tooth to undergo endodontic procedure role for " 
					     tooth-name " of patient " 
					     patient-id)) axioms)


         ;; declare instance of endodontic procedure
	 (setf endodontic-procedure-uri
	       (get-eaglesoft-endodontic-procedure-iri patient-id tooth-name record-count))
	 
	 (push `(declaration (named-individual ,endodontic-procedure-uri)) axioms)
	 (setf temp-axioms (get-ohd-instance-axioms endodontic-procedure-uri !'endodontic procedure'@ohd))
	 (setf axioms (append temp-axioms axioms))

	 ;; add annotation about this endodontic procedure
	 (push `(annotation-assertion !rdfs:label 
				      ,endodontic-procedure-uri
				      ,(str+ "endodontic procedure performed on " 
					     tooth-name " of patient " 
					     patient-id)) axioms)

	 ;; add data property !ohd:'occurrence date' to endodontic procedure
	 (push `(data-property-assertion !'occurrence date'@ohd
					 ,endodontic-procedure-uri
					 (:literal ,occurrence-date !xsd:date)) axioms)

	 ;; get axioms that describe how the endo procedure realizes the patient and provider roles
	 (setf temp-axioms (get-eaglesoft-patient-provider-realization-axioms 
			    endodontic-procedure-uri patient-id provider-id provider-type record-count))
	 (setf axioms (append temp-axioms axioms))
	 
         ;; declare instance of cdt code as identified by the ada code that is about the procedure
	 (setf cdt-class-uri (get-cdt-class-iri ada-code))
	 (setf cdt-uri (get-eaglesoft-cdt-instance-iri patient-id ada-code cdt-class-uri record-count))
	 (push `(declaration (named-individual ,cdt-uri)) axioms)
	 (setf temp-axioms (get-ohd-instance-axioms cdt-uri cdt-class-uri))
	 (setf axioms (append temp-axioms axioms))
	 
	 ;; add annotion about cdt code
	 (push `(annotation-assertion !rdfs:label
				      ,cdt-uri
				      ,(str+ "billing code " ada-code " for endodontic procedure on "
					     tooth-name " of patient " patient-id)) axioms)
	 

	  ;;;; relate instances ;;;;
	 
	 ;; tooth is located in the patient
	 (push `(object-property-assertion !'is part of'@ohd
					   ,tooth-uri ,patient-uri) axioms)
	 
         ;; 'tooth to undergo endodontic procedure role' inheres in tooth
	 (push `(object-property-assertion !'inheres in'@ohd
					   ,endodontic-role-uri ,tooth-uri) axioms)

         ;; 'endodontic procedure' realizes 'tooth to undergo endodontic procedure role'
	 (push `(object-property-assertion !'realizes'@ohd
					   ,endodontic-procedure-uri
					   ,endodontic-role-uri) axioms)
	 
         ;; 'endodontic procedure' has particpant tooth
	 (push `(object-property-assertion !'has participant'@ohd
					   ,endodontic-procedure-uri ,tooth-uri) axioms)

	 ;; determine the visit that procedure is part of
	 (setf visit-uri (get-eaglesoft-dental-visit-iri patient-id occurrence-date))
	 (push `(object-property-assertion !'is part of'@ohd ,endodontic-procedure-uri ,visit-uri) axioms)
	 
	  ;; cdt code instance is about the restoration process
	 (push `(object-property-assertion !'is about'@ohd
					   ,cdt-uri ,endodontic-procedure-uri) axioms)
	 
	 ) ;; end loop
    
    ;;(pprint axioms)

    ;; return axioms
    axioms))

(defun get-eaglesoft-tooth-to-undergo-endodontic-procedure-role-iri 
    (patient-id tooth-name instance-count)
  "Returns an iri for a 'tooth to undergo endodontic procedure role' that is generated by the patient id, the name of the type of the tooth, and a count variable that used differientiate tooth role intances that have the same patient-id/tooth-name but are numerically distinct."
  (let ((uri nil))
    (setf uri 
	  (get-unique-individual-iri patient-id 
				     :salt *eaglesoft-salt*
				     :iri-base *eaglesoft-individual-teeth-iri-base*
				     :class-type !'tooth to undergo endodontic procedure role'@ohd
				     :args `(,tooth-name ,instance-count "eaglesoft")))
    ;; return uri
    uri))

(defun get-eaglesoft-endodontic-procedure-iri (patient-id tooth-name instance-count)
  "Returns an iri for an endodontic procedure is generated by the patient id, the name of the type of tooth, and a count variable that used differientiate procedure intances that have the same patient-id/restoration-type-iri but are numerically distinct."
  (let ((uri nil))
    (setf uri 
	  (get-unique-individual-iri patient-id 
				     :salt *eaglesoft-salt*
				     :iri-base *eaglesoft-individual-endodontics-iri-base*
				     :class-type !'endodontic procedure'@ohd
				     :args `(,tooth-name ,instance-count "eaglesoft")))
    ;; return uri
    uri))

(defun get-eaglesoft-endodontics-query (&key patient-id tooth limit-rows)
  "Returns query string for retrieving data. The patient-id key restricts records only that patient or patients.  Multiple are patients are specified using commas; e.g: \"123, 456, 789\". The tooth key is used to limit results to a specific tooth, and can be used in combination with the patient-id. However, the tooth key only takes a single value. The limit-rows key restricts the number of records to the number specified."

#|
Returns endodontic procedure records.
Note: This has not been filtered for primary (baby) teeth.
1436 records returned
|#

  (let ((sql nil))
    ;; build query string
    (setf sql "SET rowcount 0 ")
    
    ;; SELECT clause
    (cond 
      (limit-rows
       (setf limit-rows (format nil "~a" limit-rows)) ;ensure that limit rows is a string
       (setf sql (str+ sql " SELECT  TOP " limit-rows " * "))) 
      (t (setf sql (str+ sql " SELECT * "))))

    ;; FROM clause
    (setf sql (str+ sql " FROM patient_history "))

    ;; WHERE clause
    (setf sql 
	  (str+ sql 
		"WHERE
                  RIGHT(ada_code, 4) IN 
                                ('3220',
                                 '3221',
                                 '3222',
                                 '3310',
                                 '3320',
                                 '3330',
                                 '3346',
                                 '3347',
                                 '3348',
                                 '3410',
                                 '3421',
                                 '3425',
                                 '3450',
                                 '3920' )

                 AND length(tooth_data) > 31 
                   /* older codes (previous to cdt4) being with a 0 
                      codes cdt4 (2003) and later begin with a D */
                 AND LEFT(ada_code, 1) IN ('D','0') "))

    ;; check for patient id
    (when patient-id
      (setf sql
	    (str+ sql " AND patient_id IN (" (get-single-quoted-list patient-id) ") ")))

    ;; check for tooth
    (when tooth
      ;; ensure tooth is a string
      (setf tooth (format nil "~a" tooth))
      (setf sql 
	    (str+ sql " AND substring(tooth_data, " tooth ", 1) = 'Y' ")))

     ;; ORDER BY clause
    (setf sql
	  (str+ sql " ORDER BY patient_id "))

    ;; return query string
    ;;(pprint sql)
    sql))