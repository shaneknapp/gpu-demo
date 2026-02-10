ARG PANGEO_BASE_IMAGE_TAG=master
FROM pangeo/base-image:${PANGEO_BASE_IMAGE_TAG}

# Required for nvidia drivers to work inside the image on GKE
# No-ops on other platforms - Azure doesn't need these set.
# Shouldn't negatively affect anyone, and makes life easier on GKE.
ENV PATH=${PATH}:/usr/local/nvidia/bin
ENV LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/nvidia/lib64

# Install apt packages specified in a apt.txt file if it exists.
# Unlike repo2docker, blank lines nor comments are supported here.
ONBUILD RUN echo "Checking for 'apt.txt'..." \
        ; [ -d binder ] && cd binder \
        ; [ -d .binder ] && cd .binder \
        ; if test -f "apt.txt" ; then \
        apt-get update --fix-missing > /dev/null \
        # Read apt.txt line by line, and execute apt-get install -y for each line in apt.txt
        && xargs -a apt.txt apt-get install -y \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/* \
        ; fi

# If a jupyter_notebook_config.py exists, copy it to /etc/jupyter so
# it will be read by jupyter processes when they start. This feature is
# not available in repo2docker.
ONBUILD RUN echo "Checking for 'jupyter_notebook_config.py'..." \
        ; [ -d binder ] && cd binder \
        ; [ -d .binder ] && cd .binder \
        ; if test -f "jupyter_notebook_config.py" ; then \
        mkdir -p /etc/jupyter \
        && cp jupyter_notebook_config.py /etc/jupyter \
        ; fi

ONBUILD USER ${NB_USER}

COPY environment.yml /tmp/environment.yml

RUN mamba env update --prefix ${CONDA_DIR} --file /tmp/environment.yml && \
    mamba clean --all -f -y && \
    rm -rf /tmp/environment.yml

# If a postBuild file exists, run it!
# After it's done, we try to remove any possible cruft commands there
# leave behind under $HOME - particularly stuff that jupyterlab extensions
# leave behind.
ONBUILD RUN echo "Checking for 'postBuild'..." \
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
ONBUILD RUN echo "Checking for 'start'..." \
        ; [ -d binder ] && cd binder \
        ; [ -d .binder ] && cd .binder \
        ; if test -f "start" ; then \
        chmod +x start \
        && cp start /srv/start \
        ; fi

COPY image-tests image-tests