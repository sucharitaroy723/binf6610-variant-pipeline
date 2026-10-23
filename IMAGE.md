## Base image
mambaorg/micromamba:2.0.5-ubuntu24.04
mambaorg/micromamba@sha256:1c62a28916ad7a4533555a542a5410e55ea2ed2c1e29f00c8fc3f1c8add111d5

## Versions pinned
bwa=0.7.19 samtools=1.24 bcftools=1.24 gatk4=4.6.2.0 fastqc=0.12.1 fastp=1.3.7 multiqc=1.35 git=2.47.1

## The pushed image
docker.io/sucha257/variant-call@sha256:bddff36b853d5254ab751deea50c9a8c944c0a44b7bb0503d27e486fc6e836fe

## The image in ECR
<account>.dkr.ecr.us-east-2.amazonaws.com/variant-call@sha256:5025fae64305e13e36787068f93f4c6056d1e32679605d0f48c30284fac09889

To rerun this analysis in a year, pull the immutable digest under The pushed image and run the saved pipeline with the original samplesheet, reference, input FASTQs, and per-sample/cohort CPU counts. Versions pinned records the selected packages; Base image identifies the starting image. The registry digest identifies the built software, including dependencies; a tag or a checksum of one converted SIF is not a replacement for that digest.
