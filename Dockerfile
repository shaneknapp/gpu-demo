ARG PANGEO_BASE_IMAGE_TAG=2026.01.30
FROM pangeo/pytorch-notebook:${PANGEO_BASE_IMAGE_TAG}

# needed for webpdf notebook exports in the jovyan's environment
ENV PLAYWRIGHT_BROWSERS_PATH=${CONDA_DIR}

USER root

# Install apt packages specified in a apt.txt file if it exists.
# Unlike repo2docker, blank lines nor comments are supported here.
# Install all apt packages
COPY apt.txt /tmp/apt.txt
RUN apt-get -qq update --yes && \
    apt-get -qq install --yes --no-install-recommends \
        $(grep -v ^# /tmp/apt.txt) && \
    apt-get -qq purge && \
    apt-get -qq clean && \
    rm -rf /var/lib/apt/lists/*

# If a jupyter_notebook_config.py exists, copy it to /etc/jupyter so
# it will be read by jupyter processes when they start. This feature is
# not available in repo2docker.
RUN echo "Checking for 'jupyter_notebook_config.py'..." \
        ; [ -d binder ] && cd binder \
        ; [ -d .binder ] && cd .binder \
        ; if test -f "jupyter_notebook_config.py" ; then \
        mkdir -p /etc/jupyter \
        && cp jupyter_notebook_config.py /etc/jupyter \
        ; fi

USER ${NB_USER}

COPY overrides.json ${CONDA_DIR}/share/jupyter/lab/settings

COPY environment.yml /tmp/environment.yml

RUN mamba env update --name notebook --file /tmp/environment.yml && \
    mamba clean --all -f -y

# If a postBuild file exists, run it!
# After it's done, we try to remove any possible cruft commands there
# leave behind under $HOME - particularly stuff that jupyterlab extensions
# leave behind.
RUN echo "Checking for 'postBuild'..." \
        ; [ -d binder ] && cd binder \
        ; [ -d .binder ] && cd .binder \
        ; if test -f "postBuild" ; then \
        chmod +x postBuild \
        && ./postBuild \
        && rm -rf /tmp/* \
        && rm -rf ${HOME}/.cache ${HOME}/.npm ${HOME}/.yarn \
        && rm -rf ${NB_PYTHON_PREFIX}/share/jupyter/lab/staging \
        && find ${CONDA_DIR} -follow -type f -name '*.a' -delete \
        && find ${CONDA_DIR} -follow -type f -name '*.js.map' -delete \
        ; fi

# If a start file exists, put that under /srv/start. Used in the
# same way as a start file in repo2docker.
RUN echo "Checking for 'start'..." \
        ; [ -d binder ] && cd binder \
        ; [ -d .binder ] && cd .binder \
        ; if test -f "start" ; then \
        chmod +x start \
        && cp start /srv/start \
        ; fi

USER root
RUN chown -R ${NB_USER}:${NB_USER} ${CONDA_DIR} /srv

COPY image-tests image-tests
