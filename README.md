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
However, installing all of a project's dependencies can be time consuming on Linux (which is what we use in Docker) since all packages have to be compiled from scratch.
As an example, a full tidyverse can easily take 15 minutes to install.

The renv package circumvents this by having its own cache with packages.
Packages used in renv'ed projects are installed in the cache and a symbolic link/shortcut is made from the renv'ed projects to the cache.

When making Docker images we want them to be *self-contained*, so that they can run on any host.
So my problem is how to build self-contained Docker images *fast*, that is, using a cache?


# A solution

The aforementioned article from renv's website suggests not installing packages in the image, but on the host and then allow a container created from the image to mount the renv cache on the host when it runs.
However, such an image is not self-contained.

My solution in this repository is to create two Docker images: 

- The first image consists only of the project files. When running this container it can install R packages in the format it needs *inside the container* and save them to the renv cache on the host through a mount.
- The second image copies the project along with dependencies from the host into the image.

Note that when renv's cache on the host is filled in this manner it contains Linux versions of the packages, even if the host operating system is not Linux.


# Demo projects

There are three demo projects, each in its own folder with an associated RStudio project and renv setup.

## Project

This project is very simple.
It contains a single R script loading the [here package](https://cran.r-project.org/package=here).
It is only meant to illustrate that this workflow works with a plain RStudio project.


## Shiny with K means

Based on a [demo app from the Shiny gallery](https://shiny.rstudio.com/gallery/kmeans-example.html) whose code is released under the MIT license at the time of writing in [this GitHub repository](https://github.com/rstudio/shiny-examples).

This app has no dependencies besides the [shiny package](https://cran.r-project.org/package=shiny).
When based on a Docker image with Shiny server and the shiny package there is no need to install additional packages in the renv library.
This is accomplised by allowing an external library in renv's settings.


## Shiny with K means in C++

A Shiny app looking just like the first one, but using the [ClusterR package](https://cran.r-project.org/package=ClusterR) instead of the `kmeans` function from `base`.
This illustrates how to utilize the packages already installed, renv's cache and packages with compiled code having system requirements.


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

These steps can be reverted by deleting the folder `renv/library` and reverting the changes in `renv/settings.dcf`.
I think these steps are not just sufficient, but also necessary.

The path added in `external.libraries` is the normal package library in the current `FROM` image, that is the first element in the output of `.libPaths()`.

