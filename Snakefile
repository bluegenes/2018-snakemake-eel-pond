import os
import numpy as np
import pandas as pd
from snakemake.utils import validate, min_version
min_version("5.1.2") #minimum snakemake version

# add validation. see https://github.com/snakemake-workflows/rna-seq-star-deseq2
samples = pd.read_table(config["samples"]).set_index("sample", drop=False)
#validate(samples, schema="schemas/samples.schema.yaml")

units = pd.read_table(config["samples"], dtype=str).set_index(["sample", "unit"], drop=False)
units.index = units.index.set_levels([i.astype(str) for i in units.index.levels])  # enforce str in index
#validate(units, schema="schemas/units.schema.yaml")

units['read_type'] = np.where(units['fq2'].isna(), 'se', 'pe') #PE,SE
#paired = units[units.read_type == 'pe']
#single = units[units.read_type == 'se']

def is_single_end(sample, unit, end):
    return units.loc[(sample,unit)]['read_type'] == 'se' 

# build file extensions from suffix info (+ set defaults)
base = config.get('basename','eelpond')
experiment_suffix = config.get('experiment', '')
readfilt = config['read_filtering']
trim_suffix = readfilt.get('trim_suffix', 'trimmed')
read_qual = readfilt['quality_assessment']

# build directory info --> later set all these from config file(s)
OUT_DIR = '{}_out{}'.format(base, experiment_suffix)
LOGS_DIR = os.path.join(OUT_DIR, 'logs')
TRIM_DIR = os.path.join(OUT_DIR, trim_suffix)
QC_DIR = os.path.join(OUT_DIR, 'qc')
ASSEMBLY_DIR = os.path.join(OUT_DIR, 'assembly')
QUANT_DIR = os.path.join(OUT_DIR, 'quant')

# workflow rules
include: os.path.join('rules',"fastqc.rule")
#from rules.fastqc_targets import get_targets
#targets_dir = QC_DIR
include: os.path.join("rules","trimmomatic.rule")
#from rules.trimmomatic_targets import get_targets
#targets_dir = TRIM_DIR
include: os.path.join("rules", "trinity.rule")
from rules.trinity_targets import get_targets
targets_dir = ASSEMBLY_DIR
#include: os.path.join("rules", "salmon.rule")
#from rules.salmon_targets import get_targets
#targets_dir = QUANT_DIR

TARGETS = get_targets(units, base, targets_dir)
rule all:
    input: TARGETS

##### setup singularity #####

# this container defines the underlying OS for each job when using the workflow
# with --use-conda --use-singularity
singularity: "docker://continuumio/miniconda3"

##### setup report #####

report: "report/workflow.rst"
