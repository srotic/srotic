#!/usr/bin/bash

######## Tools needed:
# Fastqc
# mukltiqc
# ddbuk
# chopper
# Path to minikraken2 database

# Activate pre-process conda environment
#conda activate cpo_preprocess

# Set up the input directory with fastq files
input_dir="/home/srotich/CPO_Analysis/test/nanopore"

# Set up output directory
output_dir="/home/srotich/CPO_Analysis/test/nanopore/results"

# create output_dir
mkdir -p $output_dir

## STEP 1: FastQC and MultiQC

# set up QC output directories
fastqc_output="${output_dir}/fastqc_output"
multiqc_output="${output_dir}/multiqc_output"

# make these directories
mkdir -p $fastqc_output
mkdir -p $multiqc_output

# Run the fastqc
for file in $input_dir/*.fastq
do
	fastqc -o $fastqc_output $file
done

# Run the multiqc
multiqc -o $multiqc_output $fastqc_output

## STEP 2: Adapter Removal using bbduk

# set up directory for adapter removal
adapter_removed="${output_dir}/adapter_removed"
# create the directory
mkdir -p $adapter_removed

# Remove adapters
for file in $input_dir/*.fastq
do
	bbduk.sh in="$file" out="${adapter_removed}/$(basename "$file")" #literal=ACTGGTTTTGGTG ktrim=r k=12 mink=5 hdist=1 tpe
done

## STEP 3: Filtering using chopper

# set up a directory for filtered sequences
filtered_dir="${output_dir}/filtered_dir"
# create filtered_dir
mkdir -p $filtered_dir

# Run the  Chopper
for file in ${adapter_removed}/*.fastq
do
	cat $file | chopper -q 1 -l 1000 > "${filtered_dir}/$(basename "$file")"
done

## STEP 4: Second  QC check

# Set up second QC check output directories
fastqc_check2="${output_dir}/fastqc_check2"
multiqc_check2="${output_dir}/multiqc_check2"

# create second QC check output directories
mkdir -p $fastqc_check2
mkdir -p $multiqc_check2

# Run FastQC
for file in $filtered_dir/*.fastq
do
	fastqc $file -o $fastqc_check2
done

# Run multiqc
multiqc $fastqc_check2 -o $multiqc_check2

## STEP 5: Taxa classification using Kraken2

# set up the directory
classified_dir="${output_dir}/classified_dir"
# create the directory
mkdir -p $classified_dir

# path to minikraken2 database
kraken2_db="/home/srotich/CPO_Analysis/minikraken2_db/minikraken2_v2_8GB_201904_UPDATE"

# Run the taxa classification
for file in $filtered_dir/*.fastq
do
	kraken2 --db "${kraken2_db}" --threads 4 -o "${classified_dir}/$(basename "$file")" --report "${classified_dir}/$(basename "$file").report" $file
	#kraken2-inspect-report $classifified_dir/*.report > $classifified_dir/*.txt
done
# rename kraken2_output files to .txt
#mv /home/srotich/CPO_Analysis/test/nanopore/results/classified_dir/*.report /home/srotich/CPO_Analysis/test/nanopore/results/classified_dir/*.txt

######### visualize kraken2 reports using krona

# set directory for krona reports
krona_reports="${output_dir}/krona_reports"
mkdir -p $krona_reports

# Run krona
ktImportTaxonomy -q 1 -t -2 -o $krona_reports/krona_output.html $classified_dir/*.report

