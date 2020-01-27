renv-docker
===========

The [renv package](https://rstudio.github.io/renv) provides isolated projects by having a package library for each project.
So even after updating packages in your main R library, packages in an renv'ed project are not affected.

This repository show how to import renv'ed projects into *self-contained* Docker images -- building on ideas from the article ["Using renv with Docker" at renv's website](https://rstudio.github.io/renv/articles/docker.html).

**Please note**: The `Dockerfile`s will most likely not run as is:

- They refer to paths on my computer.
- They use [Docker images I have created](https://github.com/robertdj/r-dockerfiles).

Both issues are easily fixed by changing the paths and `FROM` images in the `Dockerfile`s and in `renv_install.sh`.


# What problem am I trying to solve?

There is no technical problem in copying an renv'ed project into a Docker image and restoring it.
However, installing all of a project's dependencies can be time consuming on Linux (which is what we use in Docker) -- all packages have to be compiled from scratch.
As an example, a full tidyverse can easily take 15 minutes to install.

The renv package circumvents this by having its own cache with packages.
Packages used in renv'ed projects are installed in the cache and a symbolic link/shortcut is made from the renv'ed projects to the cache.

When making Docker images we want them to be *self-contained* (able to run on any host) and *minimal* (only need to have stuff, no nice to have).
But how to we build self-contained, minimal Docker images *fast*, that is, using a cache?


# A solution

The aforementioned article from renv's website suggests not installing packages in the image, but on the host and then allow a container created from the image to mount the renv cache on the host when it runs.
However, such an image is not self-contained.

My solution in this repository is to create two Docker images: 

- The first image consists only of the project files. When running this container it can install R packages in the format it needs *inside the container* and save them to the renv cache on the host through a mount.
- The second image copies the project along with dependencies from the host into the image.

Note that when renv's cache on the host is filled in this manner it contains Linux versions of the packages, even if the host operating system is not Linux.


## This demo project

This project is very simple.
It contains a single R script loading the [here package](https://cran.r-project.org/package=here) and the [glue package](https://cran.r-project.org/package=glue).
It is only meant to illustrate that this workflow works with both plain R packages and packages with compiled C code.


# The details

First build an image from `Dockerfile_install` that has just a new folder for this project and the renv cache inside the image.

```
docker build --build-arg R_VERSION=3.6.1 --tag renv-test:latest -f Dockerfile_install .
```

Second, install the project's dependencies in the freshly build image and share these with the host by mounting the host's renv cache and this folder.
The bash script `renv_install.sh` does this and afterwards it isolates the current project by copying the necessary packages from renv's cache to `renv/library`, replacing the symbolic links/shortcuts.
This makes the project isolated on the host.

Lastly, we build an image from `Dockerfile_build` that copies this project from the host to the image:

```
docker build --build-arg R_VERSION=3.6.1 --tag renv-test:latest -f Dockerfile_build .
```

Here I overwrite the first image by using the same name and tag.


# Notes

The second step above modify files on the host.
The renv cache as intended, but also the files in this project in order to isolate the project.
In particular, the file `renv/settings.dcf` is changed from

```
external.libraries:
ignored.packages:
snapshot.type: packrat
use.cache: TRUE
vcs.ignore.library: TRUE
```

to

```
external.libraries: /usr/local/lib/R/site-library
ignored.packages:
snapshot.type: packrat
use.cache: FALSE
vcs.ignore.library: TRUE
```

If we want to revert the isolation I think it is necessary to delete the folder `renv/library` and revert the changes in `renv/settings.dcf`.

The path added in `external.libraries` is the normal package library in the current `FROM` image, that is the first element in the output of `.libPaths()`.
If we already have packages installed in the image there is no reason to reinstall them in the renv library.

