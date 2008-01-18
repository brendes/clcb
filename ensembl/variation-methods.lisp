;; This packages aims at characterising the link from genes to SNPs

(in-package :clcb-ensembl)

#||
 
select * from source limit 10;
+-----------+----------------------------------+---------+
| source_id | name                             | version |
+-----------+----------------------------------+---------+
|         1 | dbSNP                            |     127 |
|         3 | HGVbase                          |      15 |
|         5 | TSC                              |       1 |
|        11 | ENSEMBL:Watson                   |    NULL |
|        10 | ENSEMBL:Venter                   |    NULL |
|         9 | Affy GenomeWideSNP_6.0           |    NULL |
|         8 | ENSEMBL:celera                   |    NULL |
|         7 | Affy GeneChip 100K Mapping Array |    NULL |
|         6 | Affy GeneChip 500K Mapping Array |    NULL |
+-----------+----------------------------------+---------+

||#

(def-view-class source ()
  ((source-id :db-type :key :type integer)
   (name :db-type base :type (string 255))
   (version :db-type base :type integer))
  (:base-table "source")
  (:documentation "This class answers how a particular variation was defined. A link from here to the variations with that same source ID is not feasible without extra constraints on the variations because of the large number that will be assigned to a single source."))

#|| 				variation
+-------------------+-----------------------------------------------------------------+------+-----+---------+----------------+
| variation_id      | int(10) unsigned                                                |      | PRI | NULL    | auto_increment |
| source_id         | int(10) unsigned                                                |      |     | 0       |                |
| name              | varchar(255)                                                    | YES  | MUL | NULL    |                |
| validation_status | set('cluster','freq','submitter','doublehit','hapmap','failed') | YES  |     | NULL    |                |
| ancestral_allele  | text                                                            | YES  |     | NULL    |                |
+-------------------+-----------------------------------------------------------------+------+-----+---------+----------------+

+--------------+-----------+------+------------------------+------------------+
| variation_id | source_id | name | validation_status      | ancestral_allele |
+--------------+-----------+------+------------------------+------------------+
|            1 |         1 | rs3  | cluster,freq,submitter | C                |
|            2 |         1 | rs4  | cluster,freq,submitter | A                |
|            3 |         1 | rs5  | NULL                   | NULL             |
|            4 |         1 | rs6  | freq                   | C                |
|            5 |         1 | rs7  | NULL                   | A                |
|            6 |         1 | rs8  | cluster,freq,submitter | C                |
|            7 |         1 | rs9  | NULL                   | NULL             |
|            8 |         1 | rs10 | cluster,freq,submitter | C                |
|            9 |         1 | rs11 | NULL                   | C                |
|           10 |         1 | rs12 | submitter              | A                |
+--------------+-----------+------+------------------------+------------------+
||#

(def-view-class variation ()
  ((variation-id :db-type :key :type integer)
   (source-id :db-type :base :type integer)
   (source :db-type :join :db-info (:join-class source
				    :foreign-key source-id
				    :home-key source-id
				    :retrieval :delayed))
   (name :db-type :key :type (string 255))
   (validation-status :db-type :base (string 15))
   (ancesteral-allele :db-type :base string))
  (:base-table "variation")
  (:documentation "This class identifies the abstract notion of a nucleotide polymorphism. The 'name' attribute is the frequently found rs0000 identifyer of a SNP. With this class is specified what to look for, but the individuum has not yet been inspected."))

#||			 allele
+--------------+------------------+------+-----+---------+----------------+
| allele_id    | int(10) unsigned |      | PRI | NULL    | auto_increment |
| variation_id | int(10) unsigned |      | MUL | 0       |                |
| allele       | varchar(255)     | YES  |     | NULL    |                |
| frequency    | float            | YES  |     | NULL    |                |
| sample_id    | int(10) unsigned | YES  |     | NULL    |                |
+--------------+------------------+------+-----+---------+----------------+

+-----------+--------------+--------+-----------+-----------+
| allele_id | variation_id | allele | frequency | sample_id |
+-----------+--------------+--------+-----------+-----------+
|         1 |            1 | C      |  0.673913 |       630 |
|         2 |            1 | C      |      0.89 |        16 |
|         3 |            1 | C      |      0.89 |       662 |
|         4 |            1 | C      |      0.93 |        18 |
|         5 |            1 | C      |      0.95 |        17 |
|         6 |            1 | C      |     0.956 |       660 |
|         7 |            1 | C      |  0.958333 |       631 |
|         8 |            1 | C      |      0.96 |        15 |
|         9 |            1 | C      |     0.967 |       659 |
|        10 |            1 | C      |     0.978 |       661 |
+-----------+--------------+--------+-----------+-----------+
10 rows in set (0.04 sec)
||#

(def-view-class allele ()
  ((allele-id :db-type :key :type integer)
   (variation-id :db-type :key :type integer)
   (variation :db-type :join :db-info (:join-class variation
				       :foreign-key variation-id
				       :home-key variation-id
				       :retrieval :delayed))
   (allele :db-type :base :type (string 255))
   (frequency :db-type :base :type float)
   (sample-id :db-type :base :type integer)
   (sample :db-type :join :db-info (:join-class sample
				    :foreign-key sample-id
				    :home-key sample-id)))
   (:base-table "allele")
   (:documentation "The allele links the abstract notion of a variation with a particular study (see class 'sample') that identified that allele. However, the sample may also refer to 'individuals'."))
  
#|| 		sample
+-------------+------------------+------+-----+---------+----------------+
| sample_id   | int(10) unsigned |      | PRI | NULL    | auto_increment |
| name        | varchar(255)     |      | MUL |         |                |
| size        | int(11)          | YES  |     | NULL    |                |
| description | text             | YES  |     | NULL    |                |
+-------------+------------------+------+-----+---------+----------------+
||#

(def-view-class sample ()
  ((sample-id :db-type :key :type integer)
   (name :db-type :key :type (string 255))
   (size :db-type :base :type integer)
   (description :db-type :base :type string))
  (:base-table "sample")
  (:documentation "The sample represents the study (or sometimes the single individuum) with a collection of individuals that was studied for SNPs."))


#||			 individual;
| +-----------------------------+---------------------------------+------+-----+---------+-------+
| | sample_id                   | int(10) unsigned                |      | PRI | 0       |       |
| | gender                      | enum('Male','Female','Unknown') |      |     | Unknown |       |
| | father_individual_sample_id | int(10) unsigned                | YES  |     | NULL    |       |
| | mother_individual_sample_id | int(10) unsigned                | YES  |     | NULL    |       |
| | individual_type_id          | int(10) unsigned                |      |     | 0       |       |
| +-----------------------------+---------------------------------+------+-----+---------+-------+
||#

(def-view-class individual ()
   ((sample-id :db-type :key :type integer)
    (gender :db-type :base :type (string 10))
    (father_individual_sample_id :db-type :base :type integer)
    (mother_individual_sample_id :db-type :base :type integer)
    (individual_type_id :db-type :base :type integer))
   (:base-table "individual")
   (:documentation "This class identifies relationships between samples."))

#||
individual_type
+--------------------+------------------+------+-----+---------+----------------+
| individual_type_id | int(10) unsigned |      | PRI | NULL    | auto_increment |
| name               | varchar(255)     |      |     |         |                |
| description        | text             | YES  |     | NULL    |                |
+--------------------+------------------+------+-----+---------+----------------+
||#

(def-view-class individual-type ()
  ((individual-type-id :db-type :key :type integer)
   (name :db-type :base :type (string 255))
   (description :db-type :base :type string))
  (:base-table "individual_type")
  (:documentation "Presentation of further information on indivuals genotyped (fully_inbred, partly_inbred, outbread, mutant)."))

#||					 transcript_variation;
+-------------------------+-------------------------------+------+-----+---------+----------------+
| transcript_variation_id | int(10) unsigned              |      | PRI | NULL    | auto_increment |
| transcript_id           | int(10) unsigned              |      | MUL | 0       |                |
| variation_feature_id    | int(10) unsigned              |      | MUL | 0       |                |
| cdna_start              | int(11)                       | YES  |     | NULL    |                |
| cdna_end                | int(11)                       | YES  |     | NULL    |                |
| translation_start       | int(11)                       | YES  |     | NULL    |                |
| translation_end         | int(11)                       | YES  |     | NULL    |                |
| peptide_allele_string   | varchar(255)                  | YES  |     | NULL    |                |
| consequence_type        | set('ESSENTIAL_SPLICE_SITE','STOP_GAINED','STOP_LOST','COMPLEX_INDEL','FRAMESHIFT_CODING','NON_SYNONYMOUS_CODING','SPLICE_SITE','SYNONYMOUS_CODING','REGULATORY_REGION','5PRIME_UTR','3PRIME_UTR','INTRONIC','UPSTREAM','DOWNSTREAM') |      | MUL |  
||#

(def-view-class transcript-variation ()
  ((transcript-variation-id :db-type :key :type integer)
   (transcript-id :db-type :key :type integer)
   (variation-feature-id :db-type :key :type integer)
   (cdna-start :db-type :base :type integer)
   (cdna-end :db-type :base :type integer)
   (translation-start :db-type :base :type integer)
   (translation-end :db-type :base :type integer)
   (peptide-allele-string :db-type :base :type integer)
   (consequence-type :db-type :base :type (string 50)))
  (:base-table "transcript_variation")
  (:documentation "A link from a transcript to a SNP."))

#|| 			variation_feature
| variation_feature_id | int(10) unsigned       |      | PRI | NULL       | auto_increment |
| seq_region_id        | int(10) unsigned       |      | MUL | 0          |                |
| seq_region_start     | int(11)                |      |     | 0          |                |
| seq_region_end       | int(11)                |      |     | 0          |                |
| seq_region_strand    | tinyint(4)             |      |     | 0          |                |
| variation_id         | int(10) unsigned       |      | MUL | 0          |                |
| allele_string        | text                   | YES  |     | NULL       |                |
| variation_name       | varchar(255)           | YES  |     | NULL       |                |
| map_weight           | int(11)                |      |     | 0          |                |
| flags                | set('genotyped')       | YES  |     | NULL       |                |
| source_id            | int(10) unsigned       |      |     | 0          |                |
| validation_status    | set('cluster','freq','submitter','doublehit','hapmap')    | YES  |     | NULL       |                |
| consequence_type     | set('ESSENTIAL_SPLICE_SITE','STOP_GAINED','STOP_LOST','COMPLEX_INDEL','FRAMESHIFT_CODING','NON_SYNONYMOUS_CODING','SPLICE_SITE','SYNONYMOUS_CODING','REGULATORY_REGION','5PRIME_UTR','3PRIME_UTR','INTRONIC','UPSTREAM','DOWNSTREAM','INTERGENIC') |      |     | INTERGENIC |                |
| +----------------------+----------------------+------+-----+------------+----------------+
||#
(def-view-class variation-feature ()
 ((variation_feature_id :db-type :key  :type integer)
  (seq_region_id        :db-type :key  :type integer)
  (seq_region_start     :db-type :base :type integer)
  (seq_region_end       :db-type :base :type integer)
  (seq_region_strand    :db-type :base :type integer)
  (variation_id         :db-type :key  :type integer)
  (allele_string        :db-type :base :type string)
  (variation_name       :db-type :base :type (string 255))
  (map_weight           :db-type :base :type integer)
  (flags                :db-type :base :type (string 15))
  (source_id            :db-type :base :type integer)
  (validation_status    :db-type :base :type (string 15))
  (consequence_type     :db-type :base :type (string 30)))
 (:base-table "variation_feature")
 (:documentation "Link from transcript_variation to the abstract representation of a validation."))


#||

select * from allele_group_allele join variation using (variation_id)
		join variation_group_variation using(variation_id)
		join variation_group using (variation_group_id)
		join variation_group_feature using (variation_group_id)
		join source on variation_group.source_id = source.source_id
limit 10;

select * from allele_group_allele join variation using (variation_id)
		join variation_feature using (variation_id) 
limit 10;

select * from allele join sample using (sample_id)
limit 10;


mysql> select * from variation_group_feature limit 10;
+----------------------------+---------------+------------------+----------------+-------------------+--------------------+----------------------+
variation_group_feature_id | seq_region_id | seq_region_start | seq_region_end | seq_region_strand | variation_group_id | variation_group_name |
+----------------------------+---------------+------------------+----------------+-------------------+--------------------+----------------------+
|                          1 |        226028 |         30190299 |       30233361 |                 1 |                  2 | PERLEGEN:B000001     |
|                          2 |        226028 |         30738720 |       30787661 |                -1 |                  3 | PERLEGEN:B000002     |
|                          3 |        226028 |         30978759 |       31009767 |                 1 |                  4 | PERLEGEN:B000003     |
|                          4 |        226028 |         36824334 |       36857707 |                 1 |                  5 | PERLEGEN:B000004     |
|                          5 |        226028 |         24318475 |       24340467 |                 1 |                  6 | PERLEGEN:B000005     |
|                          6 |        226028 |         23895381 |       23929680 |                 1 |                  7 | PERLEGEN:B000006     |
|                          7 |        226028 |         30532670 |       30567734 |                 1 |                  8 | PERLEGEN:B000007     |
|                          8 |        226028 |         24371534 |       24412984 |                 1 |                  9 | PERLEGEN:B000008     |
|                          9 |        226028 |         24192378 |       24206203 |                -1 |                 10 | PERLEGEN:B000009     |
|                         10 |        226028 |         27986621 |       28011953 |                 1 |                 11 | PERLEGEN:B000010     |
+----------------------------+---------------+------------------+----------------+-------------------+--------------------+----------------------+

mysql> select * from variation_group limit 10;
+--------------------+------------------+-----------+-----------+
variation_group_id | name             | source_id | type      |
+--------------------+------------------+-----------+-----------+
|                  1 | DBMHC:ABDR       |         1 | haplotype |
|                  2 | PERLEGEN:B000001 |         1 | haplotype |
|                  3 | PERLEGEN:B000002 |         1 | haplotype |
|                  4 | PERLEGEN:B000003 |         1 | haplotype |
|                  5 | PERLEGEN:B000004 |         1 | haplotype |
|                  6 | PERLEGEN:B000005 |         1 | haplotype |
|                  7 | PERLEGEN:B000006 |         1 | haplotype |
|                  8 | PERLEGEN:B000007 |         1 | haplotype |
|                  9 | PERLEGEN:B000008 |         1 | haplotype |
|                 10 | PERLEGEN:B000009 |         1 | haplotype |
+--------------------+------------------+-----------+-----------+
10 rows in set (0.04 sec)

mysql> desc variation_group;
+--------------------+-------------------------+------+-----+---------+----------------+
| Field              | Type                    | Null | Key | Default | Extra          |
+--------------------+-------------------------+------+-----+---------+----------------+
| variation_group_id | int(10) unsigned        |      | PRI | NULL    | auto_increment |
| name               | varchar(255)            | YES  | MUL | NULL    |                |
| source_id          | int(10) unsigned        |      |     | 0       |                |
| type               | enum('haplotype','tag') | YES  |     | NULL    |                |
+--------------------+-------------------------+------+-----+---------+----------------+
4 rows in set (0.04 sec)

mysql> select * from variation_feature limit 10;
+----------------------+---------------+------------------+----------------+-------------------+--------------+---------------+----------------+------------+-------+-----------+-------------------+-----------------------+
| variation_feature_id | seq_region_id | seq_region_start | seq_region_end | seq_region_strand | variation_id | allele_string | variation_name | map_weight | flags | source_id | validation_status | consequence_type      |
+----------------------+---------------+------------------+----------------+-------------------+--------------+---------------+----------------+------------+-------+-----------+-------------------+-----------------------+
|             12219625 |        225652 |             1454 |           1454 |                 1 |      2683771 | G/A           | rs3936235      |          1 | NULL  |         1 | cluster,doublehit | DOWNSTREAM            |
|             12219638 |        225652 |             1694 |           1694 |                 1 |      4714264 | G/A           | rs7466894      |          2 | NULL  |         1 | NULL              | DOWNSTREAM            |
|             12219640 |        225652 |             2641 |           2641 |                 1 |      5079970 | A/C           | rs7859283      |          2 | NULL  |         1 | NULL              | DOWNSTREAM            |
|             12219660 |        225652 |             3699 |           3698 |                -1 |     10239529 | -/G           | rs34505100     |          2 | NULL  |         1 | NULL              | DOWNSTREAM            |
|             12219628 |        225652 |             4240 |           4240 |                 1 |      3970869 | A/G           | rs6606566      |          2 | NULL  |         1 | cluster           | NON_SYNONYMOUS_CODING |
|             12219629 |        225652 |             4752 |           4752 |                 1 |      3970870 | C/T           | rs6606567      |          2 | NULL  |         1 | cluster           | INTRONIC              |
|             12219636 |        225652 |             5064 |           5064 |                 1 |      4676869 | G/A           | rs7389591      |          2 | NULL  |         1 | NULL              | UPSTREAM              |
|             12219641 |        225652 |             5586 |           5586 |                 1 |      5484481 | A/G           | rs9414697      |          2 | NULL  |         1 | NULL              | UPSTREAM              |
|             12219664 |        225652 |             5910 |           5909 |                -1 |     11052797 | -/G           | rs35408104     |          2 | NULL  |         1 | NULL              | UPSTREAM              |
|             12219634 |        225652 |             6306 |           6306 |                 1 |      4384489 | C/T           | rs7047363      |          2 | NULL  |         1 | NULL              | UPSTREAM              |
+----------------------+---------------+------------------+----------------+-------------------+--------------+---------------+----------------+------------+-------+-----------+-------------------+-----------------------+


;; To access a strech of DNA 

Du weisst besser als ich, wie man von den seq_regions auf die absoluten Koordinaten kommt und wieder zurueck...

(defun chromosome+interval->snps (chromsome interval) 
  "Returns SNPs located in that interval."
  (let (query "select seq_region_id, seq_region_start, seq_region_end, seq_region_strand, variation_id, variation_name, consequence_type from variation_feature join homo_sapiens_core_47_36i.seq_region using (seq_region_id) where ....)
    ))
||#
