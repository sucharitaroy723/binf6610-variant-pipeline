# Variant pipeline, built for linux/amd64 by the Mac helper.
FROM mambaorg/micromamba:2.0.5-ubuntu24.04
COPY --chown=mambauser:mambauser env.yml /tmp/variant-env.yml
RUN micromamba install -y -n base --override-channels \
      -c conda-forge -c bioconda -f /tmp/variant-env.yml \
 && micromamba clean --all --yes
ENV PATH=/opt/conda/bin:$PATH
USER mambauser
