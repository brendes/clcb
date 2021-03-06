;;;; Copyright (c) 2007 Albert Krewinkel
;;;;
;;;; Permission is hereby granted, free of charge, to any person
;;;; obtaining a copy of this software and associated documentation
;;;; files (the "Software"), to deal in the Software without
;;;; restriction, including without limitation the rights to use,
;;;; copy, modify, merge, publish, distribute, sublicense, and/or sell
;;;; copies of the Software, and to permit persons to whom the
;;;; Software is furnished to do so, subject to the following
;;;; conditions:
;;;;
;;;; The above copyright notice and this permission notice shall be
;;;; included in all copies or substantial portions of the Software.
;;;;
;;;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;;;; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
;;;; OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
;;;; NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
;;;; HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
;;;; WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
;;;; FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
;;;; OTHER DEALINGS IN THE SOFTWARE.

(in-package :ensembl)


(defparameter *coordinate-systems* (select 'coord-system :flatp t))



;;; fetch objects from the MySQL database
;;; -------------------------------------
(declaim (inline select1))
(defun select1 (&rest select-args)
  "Select exactly one."
  (car (apply #'select (nconc select-args '(:limit 1 :flatp t)))))

(defgeneric fetch-by-name (name object-type)
  (:documentation "Get an EnsEMBL object of type `object-type' by its name.")
  (:method (name (object-type (eql 'coord-system)))
    (list name object-type)))

(defun ensembl-type-char->type (char)
  "Transforms single letters abbreviating the EnsEMBL types into their
CLCB full representation as GENE, TRANSCRIPT, EXON or TRANSLATION.

###Example:
* (ensembl-type-char->type #\p)
=> TRANSLATION"
  (cdr (assoc char *char-class-alist* :test #'char-equal)))

(defun stable-id->ensembl-type (string)
  "Knows if a stable ID is a gene, transcript or peptide.

###Example:
* (stable-id->ensembl-type \"ENSG00000141510\")
=>
GENE
NIL"
  (declare (type string string))
  (multiple-value-bind (ign matches)
        (ppcre:scan-to-strings "ENS([A-Z])*([TGEP])[0-9]+" string)
    (declare (ignore ign))
    (values (ensembl-type-char->type (char (aref matches 1) 0))
            (aref matches 0))))

(defun fetch-by-stable-id (stable-id)
  "Retrieves an a gene from EnsEMBL by its stable gene ID
Example:
* (defparameter *tp53* (fetch-by-stable-id \"ENSG00000141510\"))

*TP53*
* *TP53*

#<GENE {10027FDC21}>"
  (declare (type string stable-id))
  (fetch-by-stable-id-and-type stable-id (stable-id->ensembl-type stable-id)))


(defgeneric fetch-by-seq-region-name (sr-name type)
  (:documentation "Fetch by the name of the seq region (e.g. 'X').")
  (:method (sr-name type)
    (select type :where
            (sql-and (sql-= (sql-slot-value 'seq-region 'name)
                            sr-name)
                     (sql-= (sql-slot-value 'seq-region 'seq-region-id)
                            (sql-slot-value type 'seq-region-id)))
            :flatp t)))

;; Note that objects with stable id can also be fetch with
;; fetch-by-stable-id; the method definitions are in ensembl-class.lisp


;;; ------------------------------------
;;; Slot reader functions and methods
;;; ------------------------------------
;; Note: We don't support writer methods yet
(defun ensembl-version (ensembl-obj)
  "Genes may vary in their sequence, e.g. because of differently
identified exons or some resequencing. This function retrieves the
version that is currently being assigned to the gene.

###Example:
(ensembl-version (sample_gene_tp53))

4"
  (slot-value (slot-value ensembl-obj 'stable-id) 'version))

(defun ensembl-biotype (ensembl-obj)
  "Type of sequence. It may be protein-coding, microRNA or something else.
* (ensembl-biotype (sample_gene_tp53))

\"protein_coding\""
  (slot-value ensembl-obj 'biotype))

(defun ensembl-status (ensembl-obj)
  "Genes differ in the degree of reliability one has in their
existance. The most reliable genes are flagged as \"known\".

###Example
* (ensembl-status (sample_gene_tp53))

\"KNOWN\" "
  (slot-value ensembl-obj 'status))


(defgeneric stable-id (ensembl-obj)
  (:documentation "Get the EnsEMBL stable id of an object.

   ###Example:
   * (stable-id (sample_gene_tp53))

   \"ENSG00000141510\" ")

  (:method (ensembl-obj)
     (slot-value (slot-value ensembl-obj 'stable-id)
              'stable-id)))


(defgeneric strand (bio-sequence)
  (:documentation "Returns +1 or -1 for the plus or minus strand of
   bio-sequence, respectively.

   ###Example:
   * (strand (sample_gene_tp53))
      
   -1")
  (:method (ensembl-obj) (slot-value ensembl-obj 'seq-region-strand)))


(defgeneric transcript (ens-obj)
  (:documentation "Return the transcript corresponding to the object,
   or nil if there is no such transcript.")
  (:method ((trans translation)) (slot-value trans 'transcript))
  (:method ((exon exon))
    (slot-value (slot-value exon 'exon-transcript) 'transcript)))

(defgeneric transcripts (ens-obj)
  (:documentation "Return a list of all transcripts corresponding to
   the object, or nil if no such transcript exists.
   
   ###Example:
   * (transcripts (sample_gene_tp53))
   
   (#<TRANSCRIPT {100293BCE1}> #<TRANSCRIPT {100293CF61}>
    #<TRANSCRIPT {100293E1E1}>)")
  (:method ((gene gene)) (slot-value gene 'transcript))
  (:method ((exon exon))
    (mapcar #'(lambda (exon-transcript)
                (car (slot-value exon-transcript 'transcript)))
            (slot-value exon 'exon-transcript))))


(defgeneric exons (ens-obj)
  (:documentation "Return a list of all exons within the object, or
   nil if there are no exons.
   Example:
   Untested: (exons (car (transcripts (sample_gene_tp53))))
   ")
  (:method ((transcript transcript))
    (mapcar #'(lambda (et) (car (slot-value et 'exon)))
            (slot-value transcript 'exon-transcript)))
  (:method ((gene gene))
    (remove-duplicates (mapcan #'exons (transcripts gene)))))


(defgeneric gene (ens-obj)
  (:documentation "Return the gene corresponding to the object, or nil
   if there is no such gene.")
  (:method (obj) (declare (ignore obj)) nil)
  (:method ((gene gene)) gene)
  (:method ((trans transcript)) (slot-value trans 'gene))
  (:method ((exon exon)) (gene (transcript exon))))

(defgeneric translation (seq-obj)
  (:documentation "Translation for an object that is either a
   transcript sequence or already a protein sequence itself. Also the
   sequence object may be a mere fragment of a real protein. In that latter
   case, CBCL refers to it as a protein-feature.
   
   Example:
   * (translation  (car (transcripts (sample-gene-rhodopsin))))
   
   #<TRANSLATION {BA81B61}>")
  (:method ((trans transcript)) (slot-value trans 'translation))
  (:method ((pep translation)) pep)
  (:method ((pf protein-feature)) (slot-value pf 'translation)))

(defgeneric chromosome (ensembl-object)
  (:documentation "Return the chromosome this object is on, or nil if
   this info is not available. The function returns a string, not a number,
   because of the genosomes X and Y.
   
   Example

   * (chromosome (sample-gene-rhodopsin))

   \"3\"")
  (:method ((seq dna-sequence)) (slot-value (seq-region seq) 'name)))


(defmethod chromosome ((ensembl-obj ensembl-object))
  ;; FIXME: Testing using only the coord-system-id might introduce
  ;; bugs in later versions of ensembl
  (with-slots ((chr-name name) (csi coord-system-id))
      (slot-value ensembl-obj 'seq-region) 
      ;; FIXME:check if we have the name of the chromosome or
      ;; something else.
    chr-name))

(defgeneric coordinate-system (ens-obj)
  (:documentation "Return the coordinate system of the object."))
(defmethod coordinate-system ((ens-obj dna-sequence))
  (slot-value (slot-value ens-obj 'seq-region)
              'coord-system))


;;; Bio Sequences
;;; -------------
(defmethod seq-length ((ens-obj dna-sequence))
  "The length of the sequence on the genome.

   ###Example:
   * (seq-length (sample-gene-rhodopsin))
   
   6695
   * (seq-length (sample-gene-tp53))
   
   19197"
  (with-slots ((seq-start seq-region-start)
               (seq-end   seq-region-end))
      ens-obj
   (abs (- seq-end seq-start))))



;;; Protein features
;;; ----------------
(defgeneric protein-features-of-type (protein feat-type)
  (:documentation "Get all protein-features of a certain type for the
   given protein. If type is nil, all features of the protein are returned
   
   Example:
   
   * (defparameter *ts* (car (transcripts (sample-gene-rhodopsin))))
   * (defparameter *tl* (translation *ts*))
   * (protein-features-of-type *tl* \"transmembrane\")
   
   (#<PROTEIN-FEATURE {BA8E7E9}> #<PROTEIN-FEATURE {BA8F051}>
    #<PROTEIN-FEATURE {BA8F8B9}> #<PROTEIN-FEATURE {BA90129}>
    #<PROTEIN-FEATURE {BA90991}> #<PROTEIN-FEATURE {BA911F9}>
    #<PROTEIN-FEATURE {BA91A61}>)
   ")
  (:method ((transl translation) (type (eql nil)))
    (declare (ignore type))
    (slot-value transl 'protein-feature))

  (:method ((transl translation) (feat-type string))
    (remove-if-not #'(lambda (x) (string-equal (slot-value x 'db) feat-type))
                   (slot-value transl 'protein-feature)
                   :key #'(lambda (x) (slot-value x 'analysis))))

  (:method ((transl translation) (feat-type symbol))
    (protein-features transl (symbol-name feat-type))))

(defun protein-features (protein &optional feat-type)
  "Returns all sequence properties of a protein.
   
   Example:
   
   * (defparameter *ts* (car (transcripts (sample-gene-rhodopsin))))
   * (defparameter *tl* (translation *ts*))
   * (protein-features *tl*)
   (#<PROTEIN-FEATURE {BA8CEB1}> #<PROTEIN-FEATURE {BA8D719}>
        ...
    #<PROTEIN-FEATURE {BA9DC01}> #<PROTEIN-FEATURE {BA9E481}>)
   "
  (protein-features-of-type protein feat-type))


(defun protein-feature-type (pf)
  "Returns the type of a particular feature. This information can be used
   to filter the retrieval of features, e.g., with the
    protein-features-of-type method.

   Example:
   
   * (defparameter *ts* (car (transcripts (sample-gene-rhodopsin))))
   * (defparameter *tl* (translation *ts*))
   * (protein-features *tl*)
   * (defparameter *ts* (car (transcripts (sample-gene-rhodopsin))))
   * (defparameter *tl* (translation *ts*))
   * (mapcar #'protein-feature-type (protein-features *tl*))
   
   (\"Pfam\" \"Pfam\" \"Superfamily\" \"transmembrane\" \"transmembrane\"
    \"transmembrane\" \"transmembrane\" \"transmembrane\" \"transmembrane\"
    \"transmembrane\" \"low_complexity\" \"Prosite_patterns\" \"Prosite_patterns\"
    \"Prosite_profiles\" \"Prints\" \"Prints\" \"Prints\" \"Prints\" \"Prints\"
    \"Prints\" \"Prints\" \"Prints\" \"Prints\" \"Prints\" \"Prints\" \"Prints\"
    \"Prints\" \"Prints\" \"Prints\" \"Prints\" \"Prints\" \"Prints\" \"Prints\"
    \"Prints\")"
  (slot-value (analysis pf)
              'db))



;;; Transmembrane
;;; -------------
(defgeneric transmembrane-protein-p (transcript-or-protein)
  (:documentation "Returns T iff the given protein (or the protein
   resulting from translating the transcript) contains a transmembrane
   region as stored in Ensembl and predicted by TMHMM.

   Example:

   * (transmembrane-protein-p (car (transcripts (sample-gene-rhodopsin))))

   T")
  (:method ((trans (eql nil))) nil)
  (:method ((tl translation)) 
    (not (null (protein-features tl "transmembrane"))))
  (:method ((ts transcript))
    (transmembrane-protein-p (translation ts))))

(defun codes-tm-protein (gene)
  "True iff at least one transcript of that genes codes for a
   transmembrane protein.

   Example:
   
   * (codes-tm-protein (sample-gene-tp53))
   
   NIL
   * (codes-tm-protein (sample-gene-rhodopsin))
   
   T "
  (some #'transmembrane-protein-p (slot-value gene 'transcript)))

(defun codes-non-tm-protein (gene)
  "True iff all transcripts of that gene are (presumed)
   soluble. Please be aware that this is not the mere complement of the
   function #'codes-tm-protein since some genes have both transmembrane
   and soluble isoforms.

   Example:
   
   * (codes-non-tm-protein (sample-gene-tp53))
   
   T
   * (codes-non-tm-protein (sample-gene-rhodopsin))
   
   NIL"
  (some (complement #'transmembrane-protein-p) (slot-value gene 'transcript)))


(defgeneric frame-preserving-p (bio-obj)
  (:documentation "Return T iff insertion or deletion of this object
   does not affect the corresponding transcripts reading frame."))
(defmethod frame-preserving-p ((exon exon))
  (zerop (mod (seq-length exon) 3)))



;;; Sequence mapping
;;; ----------------

;;; FIXME: Instead of a function taking simple integers, this should
;;; be a method that can handle different kinds of object.  It should
;;; be able to handle dna-sequence-intervals, nucleotide-intervals and
;;; amino-acid-intervals



(defgeneric aa-coords->nt-coords (coord)
  (:documentation "Convert coordinates from amino acids to
   nucleotides.  This works for simple integers as well as for intervals.
   Note that the first monomere has the index 1 in eather coordinate
   system, nucleotide as well as amino acid.  If the coordinate is a
   single number, it is mapped to the _first_ nucleotide which codes for
   the corresponding amino acid. If the argument is an interval on an
   amino acid sequence, the result is an interval that spans the whole
   nucleotide sequence which codes for the corresponding amino acids.
   
   ### Examples
   (aa->nt 1)
   => 1
   (aa->nt 3)
   => 7 "))

(defmethod aa-coords->nt-coords ((coord integer))
  (1+ (* 3 (1- coord))))

(defmethod aa-coords->nt-coords ((interval integer-interval))
  (make-interval interval
                 (aa-coords->nt-coords (lower-bound interval))
                 (+ 2 (aa-coords->nt-coords (upper-bound interval)))))


(defgeneric nt-coords->aa-coords (coord)
  (:documentation "Convert from coordinates in nucleotides to
   coordinates in amino acids."))

(defmethod nt-coords->aa-coords ((coord integer))
  (multiple-value-bind (aa-1 rest) (truncate (1- coord) 3)
    (values (1+ aa-1) rest)))

(defmethod nt-coords->aa-coords ((interval integer-interval))
  (bind:bind (((values start start-off)
               (nt-coords->aa-coords (lower-bound interval)))
              ((values end end-off)
               (nt-coords->aa-coords (upper-bound interval))))
    (values (make-interval interval  start end) start-off end-off)))

(defun aa->nt (aa-pos &optional (offset 0))
  "Convert an position given in amino acids to a position in
   nucleotides. If `offset' is given, it's interpreted as the number of
   nucleotides that should be added to the result."
  (+ (1+ (* 3 (1- aa-pos)))
     offset))

(defun nt->aa (nt-pos &optional (offset 0))
  "Convert an position given in nuleotides to a position in amino
   acids. If `offset' is given, it's interpreted as the number of
   amino acids that should be added to the result."
  (multiple-value-bind (aa-1 rest) (truncate (1- nt-pos) 3)
    (values (+ offset (1+ aa-1)) rest)))



;;; Let DNA sequence object behave like integer intervals
;;; ---------------------------------------------
(defmethod lower-bound ((interval dna-sequence))
  (slot-value interval 'seq-region-start))
(defmethod upper-bound ((interval dna-sequence))
  (slot-value interval 'seq-region-end))

(defmethod upper-bound-included-p ((ens-obj dna-sequence)) t)
(defmethod lower-bound-included-p ((ens-obj dna-sequence)) t)
;; FIXME: should be the chromosome as a dna-sequence
(defmethod interval-superset ((interval dna-sequence))
  (declare (ignore interval))
  clcb-utils::*integer-set*)

(defmethod interval-elements ((dna-seq dna-sequence))
  (with-slots ((start seq-region-start) (end seq-region-end)) dna-seq
    (- end start -1)))

(defmethod make-interval ((class (eql (find-class 'dna-sequence))) lower upper
                           &rest id-and-strand)
  (make-instance 'dna-sequence
                 :seq-region-id (car id-and-strand)
                 :seq-region-start lower
                 :seq-region-end upper
                 :seq-region-strand (cadr id-and-strand)))

(defmethod make-interval ((dna-seq dna-sequence) lower upper &rest args)
  (declare (ignore args))
  (with-slots (seq-region-id seq-region-strand) dna-seq
   (make-interval 'dna-sequence lower upper seq-region-id seq-region-strand)))

;;; -----------

(defun intron-intervals (transcript)
  (intervals (interval-relative-complement
              (make-instance 'multi-interval :intervals (exons transcript))
              transcript)))


(defun 5-prime-end-position (dna-seq)
  (if (plusp (strand dna-seq))
      (lower-bound dna-seq)
      (upper-bound dna-seq)))

(defun 3-prime-end-position (dna-seq)
  (if (plusp (strand dna-seq))
      (upper-bound dna-seq)
      (lower-bound dna-seq)))

(defun non-coding-regions (transcript)
  "Get the 3' and 5' non coding region of the transcript."
  (interval-relative-complement 
   (convex-hull (dna-sequence-interval (translation transcript)))
   (convex-hull transcript)))

(defun 5-prime-non-coding-region (transcript)
  (let ((ncr (non-coding-regions transcript)))
   (if (plusp (strand transcript))
       (first (intervals ncr))
       (second (intervals ncr)))))

(defun 3-prime-non-coding-region (transcript)
  (let ((ncr (non-coding-regions transcript)))
   (if (minusp (strand transcript))
       (first (intervals ncr))
       (second (intervals ncr)))))


(defgeneric dna-sequence-interval (ensembl-object)
  (:documentation "The genomic interval of the object.")
  
  (:method ((dna-seq dna-sequence))
    (make-interval dna-seq
                   (lower-bound dna-seq)
                   (upper-bound dna-seq)))

  (:method ((translation translation))
    (with-slots (seq-start seq-end start-exon end-exon transcript) translation
      (destructuring-bind (start . end)
          (if (plusp (strand transcript))
              (cons (+ (lower-bound start-exon) seq-start)
                    (+ (lower-bound end-exon) seq-end))
              (cons (- (upper-bound end-exon) seq-end)
                    (- (upper-bound start-exon) seq-start)))
        (interval-intersection
         (make-interval transcript start end)
         (make-instance 'multi-interval :intervals (exons transcript))))))
  
  (:method ((prot-feat protein-feature))
    (with-slots (seq-start seq-end translation) prot-feat
      (let* ((transcript (transcript translation))
             (coding-region (dna-sequence-interval translation))
             (protein-length-nt (interval-elements coding-region)))
        ;; start and stop positions on the coding region
        ;; FIXME: use aa-coords->nt-coords instead of aa->nt
        (destructuring-bind (start . end)
            (if (plusp (strand transcript))
                (cons (aa->nt seq-start) (aa->nt seq-end))
                (cons (- protein-length-nt (aa->nt seq-end))
                      (- protein-length-nt (aa->nt seq-start))))
          (interval-intersection
           (make-instance 'multi-interval :intervals (exons transcript))
           (make-interval transcript
                          (interval-nth-element coding-region start)
                          (interval-nth-element coding-region end))))))))


;;; Protein Features
;;;-----------------
(defun supporting-exons (protein-feature &optional exons)
  "All exons that code for the given protein-feature.

   Example:
   
   * (defparameter *ts* (car (transcripts (sample-gene-rhodopsin))))
   * (defparameter *tl* (translation *ts*))
   * (protein-features *tl*)
   * (defparameter *ts* (car (transcripts (sample-gene-rhodopsin))))
   * (defparameter *tl* (translation *ts*))
   * (defparameter *pf* (protein-features-of-type *tl* \"transmembrane\"))
   * (supporting-exons (car *pf*))
   
   (#<EXON {BAFA8B1}>)
   "
  (let ((pf-coding-interval (dna-sequence-interval protein-feature))
        (exons (or exons
                   (exons (transcript (translation protein-feature))))))
    (iter (for exon in exons)
          (when (not (interval-empty-p
                      (interval-intersection pf-coding-interval exon)))
            (collect exon)))))

(defgeneric main-supporting-exon (protein-feature &optional exons)
  (:documentation "Return the exon which contains the most sequence
information for the protein feature."))

(defmethod main-supporting-exon ((protein-feature protein-feature) &optional
                                 (exons
                                  (exons (transcript
                                          (translation protein-feature)))))
  "The exon that holds most of the sequence coding for the protein-feature."
  (let ((pf-coding-interval (dna-sequence-interval protein-feature)))
    (iter
      (for exon in exons)
      (for overlap = (interval-intersection pf-coding-interval exon))
      (finding exon maximizing (interval-elements overlap)))))


;;; URL handling
;;; ------------

;;; I will have to write a slime extension that lets me click on
;;; ensembl objects to fire up a browser and view an url for this
;;; object.
(defgeneric ensembl-object->url (ensembl-obj)
  (:documentation "Get the Ensembl genome browser URL for this object.
Example:

* (ensembl-object->url (sample-gene-tp53))

\"http://www.ensembl.org/Homo_sapiens/geneview?db=core;gene=ENSG00000141510\"")
  (:method ((gene gene))
    (format nil "http://www.ensembl.org/Homo_sapiens/geneview?db=core;gene=~A"
            (stable-id gene)))
  (:method ((transcript transcript))
    (format nil "http://www.ensembl.org/Homo_sapiens/transview?db=core;transcript=~A"
            (stable-id transcript)))
  (:method ((translation translation))
    (format nil "http://www.ensembl.org/Homo_sapiens/protview?db=core;peptide~A"
            (stable-id translation)))
  (:method ((exon exon))
    (format nil "http://www.ensembl.org/Homo_sapiens/exonview?exon=~A"
            (stable-id exon)))
  )







;;;; TRASH LINE
;;;; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;;;; All code past this line is untested, subject to sudden changes
;;;; and/or very very buggy.


;;; --------------------------------------------------------------------------
;;; For Tests in the REPL
;;; --------------------------------------------------------------------------
(defparameter *transcripts*
  (select 'transcript
          :where (sql-= (sql-slot-value 'transcript
                                        'seq-region-id)
                        226031)
          :limit 20
          :flatp t))

(defparameter *translations*
  (mapcar #'car
          (select 'translation
                  :limit 20)))

(defparameter *genes*
  (select 'gene :limit 20 :flatp t))

(defparameter *gene* (fetch-by-stable-id "ENSG00000079134"))

(defparameter *tp53* nil)

(defun sample-gene-tp53 () 
  "The gene tp53 is retrieved from Ensembl and stored in the parameter
*tp53*. If that parameter is already set, then it will be returned
directly. The 'Tumour Protein 53' is one of the better-studied
proteins and most biologists will immediately know its
properties. This shall contribute to making the examples better
understood.

   Example:
   
   * (SAMPLE-GENE-TP53)
   
   Gene TP53 successfully retrieved from Ensembl.
   #<GENE {10027FDC21}>
   * (SAMPLE-GENE-TP53)
   
   #<GENE {10027FDC21}>
  "
   (if *tp53*
       *tp53*
       (progn
         (if (setf *tp53* (fetch-by-stable-id "ENSG00000141510"))
             (print "Gene TP53 successfully retrieved from Ensembl.")
             (print "Gene TP53 could not be retrieved."))
         *tp53*)))

(setf *tp53* (sample-gene-tp53))

(defparameter *rhodopsin* nil)

(defun sample-gene-rhodopsin () 
  "The gene rhodopsin is retrieved from Ensembl and stored in the
parameter *rhodopsin*. If that parameter is already set, then it will
be returned directly. The gene is a prominant representant of the GPCR
protein family. This shall contribute to making the examples better
understood.
   
   Example:
   
   * (sample-gene-rhodopsin)
   
   Gene TP53 successfully retrieved from Ensembl.
   #<GENE {10027FDC21}>
   * (sample-gene-rhodopsin)
   
   #<GENE {10027FDC21}>
   "
  (if *rhodopsin* *rhodopsin*
     (progn (if (setf *rhodopsin* (fetch-by-stable-id "ENSG00000163914"))
		 (print "Gene RHO successfully retrieved from Ensembl.")
		 (print "Gene RHO could not be retrieved."))
	     *rhodopsin*)))

(setf *rhodopsin* (sample-gene-rhodopsin))



(defparameter *transcript* (car (transcripts *gene*)))

(defparameter *translation*
  (slot-value *transcript* 'translation))

(defparameter *exon* (fetch-by-stable-id "ENSE00001494481"))




(defun complement-seq (seq)
  (let* ((seq-length (length seq))
         (comp (make-string seq-length)))
    (loop for char across seq
          for i below seq-length
          do (setf (aref comp i)
                   (complement-base-char char)))
    comp))

(defun splice-transcript (trans)
  (let* ((exons (exons trans))
         (sequences (mapcar #'ensembl-sequence exons)))
    (apply #'concatenate 'string sequences)))


;; Let transcripts behave like multi-intervals
(defmethod intervals ((transcript transcript))
  (funcall (if (plusp (strand transcript)) #'identity #'reverse)
           (exons transcript)))

(defmethod interval-elements ((trans transcript))
  (reduce #'+ (exons trans)
          :key #'interval-elements))

(defmethod interval-nth-element ((trans transcript) (n integer))
  (iter (for interval in (intervals trans))
        (for num-elements = (interval-elements interval))
        (if (< num-elements n)
            (setf n (- n num-elements))
            (return (interval-nth-element interval n)))))

;(defun protein-coords->dna-coords (prot transcript &optional (pf nil)))



(defun coding-start (transl)
  (let ((start-exon (slot-value transl 'start-exon)))
    (- (seq-length start-exon)
       (slot-value transl 'seq-start))))

(defmethod sequence-level-p ((seq-region seq-region))
  (sequence-level-p (slot-value seq-region 'coord-system)))
(defmethod sequence-level-p ((coord-system coord-system))
  (not (null (search "sequence_level" (slot-value coord-system 'attrib)))))
(defmethod sequence-level-p ((asm assembly))
  (sequence-level-p (slot-value asm 'cmp-seq-region)))


;;; --------------------------------------------------------------------------
;;; Sequence retrieval
;;; --------------------------------------------------------------------------
(defgeneric component-assemblies (ensembl-obj)
  (:documentation "Get all assembly components for this EnsEMBL object."))


(defmethod component-assemblies (obj)
  (with-slots ((seq-id     seq-region-id)
               (seq-start  seq-region-start)
               (seq-end    seq-region-end))      
      obj
    (select 'assembly
            :where
            (sql-and (sql-= (sql-slot-value 'assembly 'asm-seq-region-id)
                            seq-id)
                     (sql-<= seq-start
                             (sql-slot-value 'assembly 'asm-end))
                     (sql->= seq-end
                             (sql-slot-value 'assembly 'asm-start)))
            :flatp 1)))


(defun complement-base-char (char)
  (cond ((char= char #\A) #\T)
        ((char= char #\T) #\A)
        ((char= char #\G) #\C)
        ((char= char #\C) #\G)))

(defun reverse-complement-seq (seq)
  (let* ((seq-length (length seq))
         (rev-comp (make-string seq-length)))
    (loop for char across seq
          for i downfrom (1- seq-length)
          do (setf (aref rev-comp i)
                   (complement-base-char char)))
    rev-comp))

(defun coord-system-by-db-id (id)
  (find id *coordinate-systems* 
        :key (lambda (n) (slot-value n 'coord-system-id))))

(defun best-cmp-assembly (asm-list)
  (iterate::iter
    (iterate:for asm iterate:in asm-list)
    (iterate:finding asm iterate:minimizing
                     #'(lambda (x) 
                         (slot-value (coord-system-by-db-id
                                      (slot-value (cmp-seq-region x)
                                                  'coord-system-id))
                                     'rank)))))

;; FIXME: Only to keep my prototype in a functional state.
(defun genomic-coordinates (x) (cons (lower-bound x) (upper-bound x)))

(defmethod ensembl-sequence (ens-obj)
  (let* ((assemblies (component-assemblies ens-obj))
         (seq-asm (best-cmp-assembly (remove-if-not #'sequence-level-p
                                                    assemblies))))
    (destructuring-bind (start . end)
        (mapped-seq-regions-coord (genomic-coordinates ens-obj) seq-asm)
      (funcall 
       (if (<= 0 (slot-value ens-obj 'seq-region-strand))
           #'identity
           #'reverse-complement-seq)
       (car (query (print(format nil
                                 "select substring(sequence,~A,~A) from dna ~
                                  where seq_region_id = ~A"
                                 start
                                 (- end start -1)
                                 (slot-value seq-asm 'cmp-seq-region-id)))
                   :flatp t
                   :field-names nil))))))



(defun assemblies-for-seq-regions (sr1 sr2)
  "Get the assembly object that maps from seq-region sr1 to sr2."
  (select 'assembly :where
           (sql-and (sql-= (sql-slot-value 'assembly 'asm-seq-region-id)
                           (slot-value sr1 'seq-region-id))
                    (sql-= (sql-slot-value 'assembly 'cmp-seq-region-id)
                           (slot-value sr2 'seq-region-id)))
           :flatp t))

;; We assume that the seq regions are directly connected by some
;; assembly definition.
;; (defun mapped-seq-regions-coords (coords from-seq-region to-seq-region)
;;   ())
(defun start-position (ensembl-obj)
  (slot-value ensembl-obj 'seq-region-start))
(defun end-position (ensembl-obj)
  (slot-value ensembl-obj 'seq-region-end))

(defun mapped-seq-regions-coord (coord assembly)
  (let ((start (car coord))
        (end (cdr coord)))
    (declare (type fixnum start end))
    (with-slots (asm-start asm-end cmp-start cmp-end) assembly
      (cons (+ cmp-start (- start asm-start))
            (+ cmp-start (- end asm-start))))))


(defun cmp-assemblies (start end seq-region)
  (select 'assembly
          :where
          (sql-and (sql-= (sql-slot-value 'assembly 'asm-seq-region-id)
                          (slot-value seq-region 'seq-region-id))
                   (sql-<= start
                           (sql-slot-value 'assembly 'asm-end))
                   (sql->= end
                           (sql-slot-value 'assembly 'asm-start)))
          :flatp 1))

(defgeneric map-coord-systems (pos src-cs target-cs)
  (:documentation "Map a position from one coordinate system to another."))


(defmethod map-coord-system-to-seq ((start fixnum) (end fixnum)
                                    (src-cs seq-region))
  (let* ((seq-length (- end start))
         (seq-asm (best-cmp-assembly (cmp-assemblies start end src-cs))))
    (when (null seq-asm)
      (return-from map-coord-system-to-seq src-cs))
    (if (sequence-level-p (coord-system (slot-value seq-asm
                                                    'asm-seq-region)))
        (slot-value seq-asm 'asm-seq-region)
        (map-coord-system-to-seq (- start
                                    (slot-value seq-asm 'asm-start))
                                 (+ (- start
                                       (slot-value seq-asm 'asm-start))
                                    seq-length)
                                 (slot-value seq-asm 'asm-seq-region)))))





(defun coords (x) (cons (lower-bound x) (upper-bound x)))



#||;; This causes problems for some reason I coudn't figure out.
(defmethod print-object ((seq dna-sequence) (stream stream))
  (print-unreadable-object (seq stream :type t)
    (format stream "~A:[~A,~A]"
             (chromosome seq) (lower-bound seq) (upper-bound seq))))

||#


(defmethod homology-ids ((g gene))
  "Returns the list of IDs in Ensembl Compara to which exactly this
single gene is assigned."
  (gene-stable-id->homology-ids (stable-id g) nil))

(defgeneric homologues (ensembl-obj)
  (:documentation "List all IDs that are in homology to a given
  object. For genes this will return the information from the homology
  assignment in Ensembl Compara."))


(defmethod homologues ((g gene))
  "For genes, the homology between two entries is defined by the
Compara table of the same name."
  (let* ((homology-ids (gene-stable-id->homology-ids (stable-id g) nil))
         (stable-ids (homology-id->gene-stable-ids homology-ids)))
    (mapcar #'fetch-by-stable-id stable-ids)))

(defmethod homologues ((p translation))
  "For translated gene products, a range of very different approaches
  are available, not yet implemented."  
  nil)

(defmethod homologues ((pf protein-feature))
  "For translated gene products, a range of very different approaches
  are available, not yet implemented."
  nil)
