# Variant pipeline, built from the repository root.
FROM mambaorg/micromamba:2.0.5-ubuntu24.04
COPY --chown=mambauser:mambauser containers/env.yml /tmp/variant-env.yml
RUN micromamba install -y -n base --override-channels \
      -c conda-forge -c bioconda -f /tmp/variant-env.yml \
 && micromamba clean --all --yes
ENV PATH=/opt/conda/bin:$PATH
USER mambauser

COPY --from=public.ecr.aws/aws-cli/aws-cli:2.37.12 /usr/local/aws-cli /usr/local/aws-cli
USER root
RUN ln -s /usr/local/aws-cli/v2/current/bin/aws /usr/local/bin/aws
USER $MAMBA_USER
COPY --chown=$MAMBA_USER:$MAMBA_USER . /pipeline/
COPY --chown=$MAMBA_USER:$MAMBA_USER aws/batch_run.sh /usr/local/bin/batch_run.sh
