renv-docker
===========

The [{renv} package](https://rstudio.github.io/renv) provides isolated projects by having a package library for each project.
So even after updating packages in your main R library, packages in an renv'ed project are not affected.

This repository show how to import renv'ed projects into *self-contained* Docker images -- building on ideas from the article ["Using renv with Docker" at {renv}'s website](https://rstudio.github.io/renv/articles/docker.html).

**Please note**: The `Dockerfile`s will most likely not run as is because the path to {renv}'s cache on the host is a path on my computer (`/home/robert/code/R/renv-cache`).
But change the path in the `renv_install.sh` scripts and it should work.

To see the path to {renv}'s cache run `renv::paths$cache()`.
The path can be changed by setting the environment variable `RENV_PATHS_CACHE` like in the `renv_install.sh` scripts.


# What problem am I trying to solve?

There is no technical problem in copying an renv'ed project into a Docker image and restoring it.
However, installing all of a project's dependencies can be time consuming on Linux (which is what we use in Docker) since all packages have to be compiled from scratch.
As an example, a full tidyverse can easily take 15 minutes to install.

The {renv} package circumvents this by having its own cache with packages.
Packages used in renv'ed projects are installed in the cache and a symbolic link/shortcut is made from the renv'ed projects to the cache.

When making Docker images we want them to be *self-contained*, so that they can run on any host.
So my problem is how to build self-contained Docker images *fast*, that is, using a cache.


A nice side-effect of installing packages in the manner described here is that it is easy to include packages from private CRANs requiring authentication.
More details are provided later.


# A solution

The aforementioned article from {renv}'s website suggests not installing packages in the image, but on the host and then allow a container created from the image to mount {renv}'s cache on the host when it runs.
However, such an image is not self-contained.

My solution in this repository is to create two Docker images: 

- The "install image": The first image consists only of the prerequisites for the projects. When running a container from this image it can install R packages in the format it needs *inside the container* and save them to {renv}'s cache on the host through a mount.
- The "final image": The second image copies the project along with dependencies from the host into the image.

Note that when {renv}'s cache on the host is filled in this manner it contains Linux versions of the packages, even if the host operating system is not Linux.


# Demo projects

There are three demo projects, each in its own folder with an associated RStudio project and {renv} setup.

The examples with Shiny server use a simple configuration file with an elaborate URL for the demo app.
Check out [Shiny server's docs](https://docs.rstudio.com/shiny-server) to learn more about its configuration.


## Here

This project is very simple.
It contains a single R script loading the [{here} package](https://cran.r-project.org/package=here).
Due to the minimal requirements of the {here} package, the "install image" just sets the working directory.

The path to reconstruction is:

1. Navigate to the `here` folder.
2. Build the "install image":

```
docker build --build-arg R_VERSION=4.1.1 --tag renv-test:latest -f Dockerfile_install .
```

3. Restore the project inside the container by running the `renv_install.sh` script.
4. Build the final image:

```
docker build --build-arg R_VERSION=4.1.1 --tag renv-test:latest .
```

Check out a running container with this command:

```
docker run --rm -it renv-test:latest
```

You should see {renv} being activated and the {here} package should be available:

```
* Project '~/project' loaded. [renv 0.12.0]
> library(here)
here() starts at /home/shiny/project
```


## Shiny with K means

Based on a [demo app from the Shiny gallery](https://shiny.rstudio.com/gallery/kmeans-example.html) whose code is released under the MIT license at the time of writing in [this GitHub repository](https://github.com/rstudio/shiny-examples).

This app has no dependencies besides the [{shiny} package](https://cran.r-project.org/package=shiny).
When based on a Docker image with the {shiny} package installed there is no need to install additional packages in the {renv} library.
This is accomplished by allowing an external library in {renv}'s settings.

The path to reconstruction is:

1. Navigate to the `shiny_kmeans` folder.
2. Build the "install image":

```
docker build --build-arg R_VERSION=4.1.1 --build-arg SHINY_VERSION=1.5.17.973 --tag renv-test:latest -f Dockerfile_install .
```

3. Restore the project inside the container by running the `renv_install.sh` script.
4. Build the final image:

```
docker build --build-arg R_VERSION=4.1.1 --build-arg SHINY_VERSION=1.5.17.973 --tag renv-test:latest .
```

Check out a running container with this command (where `3839` is an example port):

```
docker run --rm -p 3839:3838 renv-test:latest
```

You should see Shiny server starting. 
Navigate to <http://localhost:3839/project> to see the Shiny app.


## Shiny with K means in C++

A Shiny app looking just like the first one, but using the [{ClusterR} package](https://cran.r-project.org/package=ClusterR) to perform K means clustering instead of the `kmeans` function from {stats}.
This illustrates how to utilize the packages already installed, {renv}'s cache and packages with compiled code having system requirements.

It can be tedious to find system requirements for packages.
I know of two ways:

* The [{remotes} package](https://remotes.r-lib.org) has the function `system_requirements`. Here is a [nice walkthrough](https://mdneuzerling.com/post/determining-system-dependencies-for-r-projects).
* My own unofficial [{pkg.deps} package](https://github.com/robertdj/pkg.deps) that does the same as `system_requirements` without calling an RStudio Package Manager server. (Made before I became aware that {remotes} offers the same.)

The path to reconstruction is:

1. Navigate to the `shiny_kmeans_rcpp` folder.
2. Build the "install image":

```
DOCKER_BUILDKIT=1 docker build --build-arg R_VERSION=4.1.1 --build-arg SHINY_VERSION=1.5.17.973 --tag renv-test:latest -f Dockerfile_install .
```

3. Restore the project inside the container by running the `renv_install.sh` script.
4. Build the final image:

```
DOCKER_BUILDKIT=1 docker build --build-arg R_VERSION=4.1.1 --build-arg SHINY_VERSION=4.1.1-1.5.17.973 --tag renv-test:latest .
```

Check out a running container with this command (where `3839` is an example port):

```
docker run --rm -p 3839:3838 renv-test:latest
```

You should see Shiny server starting. 
Navigate to <http://localhost:3839/project> to see the Shiny app.


# Files on host

Note that the `renv_install.sh` scripts modify files on the host.

It modifies {renv}'s cache as intended, but also the files in the project in order to isolate the project.
In particular, the file `renv/settings.dcf` is changed from something like

```
external.libraries:
ignored.packages:
package.dependency.fields: Imports, Depends, LinkingTo
r.version:
snapshot.type: implicit
use.cache: TRUE
vcs.ignore.library: TRUE
vcs.ignore.local: TRUE
```

to

```
external.libraries: /usr/local/lib/R/site-library
ignored.packages:
package.dependency.fields: Imports, Depends, LinkingTo
r.version:
snapshot.type: implicit
use.cache: TRUE
vcs.ignore.library: TRUE
vcs.ignore.local: TRUE
```

These steps can be reverted by deleting the folder `renv/library` and reverting the changes in `renv/settings.dcf`.
I think these steps are not just sufficient, but also necessary.

The path added in `external.libraries` is the normal package library in the current `FROM` image -- that is, the first element in the output of `.libPaths()`.


# Private CRANs

At work I use a number of internal packages stored in a private CRAN that rely on authentication through HTTP (basic HTTP access with username/password in the URL or bearer authentication with a token in the header).

The approach here to install with a running container makes it easy to share these credentials as environment variables with e.g. a `-e` argument to a `docker run`.

This is very different from trying to install packages *at build time*, because it is difficult to make environment variables availabe in a *non-persistent manner* at image build time.

