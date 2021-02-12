# Contributing

Contributions are warmly welcomed!  To avoid any misunderstandings, do please first discuss the change you wish to make via issue, email, or any other method with the owners of this repository before submitting a PR.

Please note we have a [code of conduct](https://www.contributor-covenant.org/version/2/0/code_of_conduct/), please follow it in all your interactions with the project.

# Environment Setup

This repository makes use of the [SASjs](https://sasjs.io) framework for code organisation, compilation, documentation, and deployment.  The following tools are highly recommended:

* [NPM](https://sasjs.io/windows/#npm) - the runtime and dependency manager for [SASjs CLI](https://cli.sasjs.io) (batteries included)
* [VSCode](https://sasjs.io/windows/#vscode) - feature packed IDE for code editing (warning - highly effective!)
* [GIT](https://sasjs.io/windows/#git) - a safety net you cannot (and should not) do without.

For generating the documentation (`sasjs doc`) it is also necessary to install [doxygen](https://www.doxygen.nl/manual/install.html).


To get configured:

1.  Clone the repository
2.  Install local dependencies (`npm install`)
3.  Install the SASjs CLI globally (`npm install -g @sasjs/cli`)
4.  Add a target, and authentication (`npm add`).  See [docs](https://cli.sasjs.io/add/).

To contribute:

1.  Create your feature branch (`git checkout -b myfeature`)
2.  Make your change
3.  Update the `all.sas` file (`python3 build.py`)
4.  Commit the change, using the [conventional commit](https://www.conventionalcommits.org/en/v1.0.0) standard
5.  Push and make a PR

