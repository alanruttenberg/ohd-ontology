;;(defparameter *ohd-label-source* nil)
(defparameter *ohd-label-source*
  (make-instance 'label-source
		 :key :ohd
		 :sources '("ohd:imports;fma-jaws-teeth.owl"
			    "ohd:imports;icd9-import.owl"
			    "ohd:ontology;vdw-elderly-restoration-longevity-research.owl"
			    "ohd:ontology;ohd.owl"
			    "ohd:imports;BFO2;bfo2-classes.owl"
			    "ohd:imports;BFO2;bfo2-relations.owl")))

(defun add-alternative-terms-to-label-source ()
  "adds the alternative terms from the ontology to the label-source hash table"
  (let (table ohd query results)
    ;; load ohd ontology
    (setf ohd (load-ontology "ohd:ontology;ohd.owl" :reasoner :none))

    ;; build query string
    (setf query 
	  (str+ "select ?term ?uri "
		"where {?uri <" (uri-full !'alternative term'@ohd) "> ?term . } "))
    
    ;; query ontology to get a list of alternative terms and uri
    (setf results
	  (sparql query :kb ohd :use-reasoner :none))
    
    ;; set a pointer to label2uri hash table
    (setf table (label2uri *ohd-label-source*))

    ;; add results of sparql query to hash table
    (loop 
       for r in results
       for term = (first r)
       for uri = (second r)
       do
	 (setf (gethash term table) uri))

    ;; return hash table
    table))

(defun add-tooth-numbers-to-label-source ()
  "adds the alternative terms from the ontology to the label-source hash table"
  (let (table ohd query results)
    ;; load ohd ontology
    (setf ohd (load-ontology "ohd:ontology;ohd.owl" :reasoner :none))

    ;; build query string
    (setf query 
	  (str+ "select ?term ?uri "
		"where {?uri <" (uri-full !'ADA universal tooth number'@ohd) "> ?term . } "))
    
    ;; query ontology to get a list of alternative terms and uri
    (setf results
	  (sparql query :kb ohd :use-reasoner :none))
    
    ;; set a pointer to label2uri hash table
    (setf table (label2uri *ohd-label-source*))

    ;; add results of sparql query to hash table
    (loop 
       for r in results
       for term = (first r)
       for uri = (second r)
       do
	 (setf (gethash term table) uri))

    ;; return hash table
    table))

;; ********** add alternative terms and tooth numbers to OHD label source ***********
(add-alternative-terms-to-label-source)
(add-tooth-numbers-to-label-source)

(defun get-copy-ohd-label-source ()
  "Makes and returns a copy of the *ohd-label-source* hash table created in make-uri-from-label-source."
  (let ((label-copy-ht (make-hash-table :test 'equalp))
	(uri nil))
  
    ;; make sure *ohd-label-source* hash table exists)
    (when (not (hash-table-p *ohd-label-source*))
      ;; create *ohd-label-source*
      (setf uri !'Tooth'@ohd))

    ;; loop over *ohd-label-source* can copy values
    (loop 
       for k being the hash-keys in *ohd-label-source*
       using (hash-value v) do
       (setf (gethash k label-copy-ht) v))

    ;; return copy of hash table
    label-copy-ht))

(defun compare-ontology-rdfs-labels (ont1 ont2)
  "Compares the rdfs:labels for the uris in two ontologies, and prints to the screen the uris (and the uri's label) in which the labels of each ontology do not match."
  (let ((ont1-labels nil)
	(ont2-labels nil)
	(diff-labels nil))

    ;; get the (uri rdfs:label) list of each ontology
    (setf ont1-labels 
	  (loop 
	     for k being the hash-keys in (rdfs-labels ont1) using (hash-value v) 
	     collect (format nil "~a ~a" k (car v))))
	     ;;collect (format nil "~a" (car v))))

    (setf ont2-labels 
	  (loop 
	     for k being the hash-keys in (rdfs-labels ont2) using (hash-value v)
	     collect (format nil "~a ~a" k (car v))))
	     ;;collect (format nil "~a" (car v))))


    ;; get the set difference of each
    (setf diff-labels (set-difference ont1-labels ont2-labels :test 'equalp))
    
    ;; return the diff labels (if any)
    diff-labels))
