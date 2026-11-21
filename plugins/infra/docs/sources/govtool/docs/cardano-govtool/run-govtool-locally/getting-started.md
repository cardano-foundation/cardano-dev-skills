# Getting Started

## Prerequisites

* It is heavily advised that the repos for all the pillars of GovTool that you would like to deploy be forked into your own local copy. (Each section title links back to the parent repo, links can also be found in the README file of this repo)
* After forking the repo it is recommended to have a look at the Check and Build workflows as these are used by the respective upstream repos to build the images used in production. [Build Workflow Links](./quick-links.md)
* Each of the Upstream repos will use environment variables similar to those which are listed in the **env-vars.yaml** files for each respective pillar. The GovTool backend reads `GOVTOOL_*` environment variables, listed in [`govtool-backend/.env.example`](https://github.com/IntersectMBO/govtool/blob/develop/govtool/govtool-backend/.env.example); for deployment purposes the db-sync credentials among them should be treated as a secret
* As this was designed to be run locally using a Minikube cluster it is advised to have Docker installed and a Minikube Image downloaded locally [Guide Links](./quick-links.md)

## Pillar Naming Conventions

Throughout this Wiki section you may find multiple references to backend and frontend services for the sake of clarity the following will be true:

* pdf backend will reference the GovTool Proposal Pillar backend
* backend will reference the Core GovTool Backend, which also serves the Governance Actions Outcomes
* metadata will reference the Core GovTool Metadata Service (`govtool-metadata-service`), which the backend uses to resolve and check metadata
* frontend will reference the Core GovTool Frontend UI

