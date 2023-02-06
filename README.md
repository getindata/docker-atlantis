# Docker Atlantis Image

<!--- Build Badges -->
[![build test scan docker images](https://github.com/getindata/docker-atlantis/actions/workflows/pr_opened.yml/badge.svg)](https://github.com/getindata/docker-atlantis/actions/workflows/pr_opened.yml)
[![create new release with changelog](https://github.com/getindata/docker-atlantis/actions/workflows/release.yml/badge.svg)](https://github.com/getindata/docker-atlantis/actions/workflows/release.yml)

<!--- Replace repository name -->
![Docker](https://badgen.net/badge/icon/docker?icon=docker&label)
![License](https://badgen.net/github/license/getindata/docker-atlantis/)
![Release](https://badgen.net/github/release/getindata/docker-atlantis/)


<p align="center">
  <img height="150" src="https://getindata.com/img/logo.svg">
  <h3 align="center">We help companies turn their data into assets</h3>
</p>

That custom `atlantis` docker image was created in order to install few helpful tools into "stock" solution:
- `terragrunt-atlantis-config` - script that dynamically generates `atlantis.yaml` for terragrunt configurations
- `checkov` - security and "best-practice" scanner (static code analysis)
- `asdf` - version manager used to install needed packeges and versions <http://asdf-vm.com/>
- `terragrunt` (via asdf) - thin terraform wrapper
- `terraform` (via asdf) - IaC automation
- `helm` (via asdf) - k8s package manager used by `helm` terraform provider
- `kubectl` (via asdf) - k8s CLI tool used by `kubernetes` terraform provider
- `jq` (via asdf) - command line JSON parser
- `yq` (via asdf) - command like YAML parser
- `glab` (via asdf) - GitLab CLI client
- `az-cli` (via pip) - Azure CLI
- 
Files found in the repo:
- `Dockerfile` is based on an official atlantis docker file (<https://github.com/runatlantis/atlantis/blob/v0.17.3/Dockerfile>) with some additional tweaks (asdf installation and configuration)
- `docker-entrypoint.sh` is based on original file from atlantis repo <https://github.com/runatlantis/atlantis/blob/v0.19.8/docker-entrypoint.sh> with additional tweaks like invoking `bash` to run `atlantis` (due to `asdf` needs)
- `check-gitlab-approvals.sh` is a script, intended to work around GitLab CE repository security limitations (CODEOWNERS, allowed approvers, etc.)
- `approval-config-example.yaml` is a sample approver config used by `check-gitlab-approvers.sh` script

---

## Work around Free GitLab limitations

Free versions of all major VCS systems (GitHub, GitLab, Bitbucket) introduce a set of limitations that should encourage it's users to pay for the service. One of those limitations is no `CODEOWNERS` support
and no ability to configure "allowed approvers" in free repositories.

Since Atlantis security depends on VCS level reviews (every approved MR/PR can be `atlantis apply`ed) it is crucial to somehow workaround this limitations.

We use hosted GitLab as our primary VCS in GetInData, also self-hosted version of GitLab is very popular among our clients. We're also big fans of Atlantis and engineers in the same time - which took us to obvious conclusions -
we should create a solution that allows our clients to use self-hosted GitLab CE and Atlantis securely.

As a result we created a simple bash script [check-gitlab-approval.sh](check-gitlab-approvals.sh) that uses GitLab CLI called `glab` and few other popular bash tools to verify MR approvals. Script's configuration is stored in
yaml format and can be mounted/saved into the image or passed via environment variable, example configuration can be found [here](approval-config-example.yaml).

This script is intended to be used as one of `apply` steps in custom Atlantis workflow, example:

```yaml
workflows:
  myworkflow:
    plan:
      steps:
        - init
        - plan
    apply:
      steps:
        - run: check-gitlab-approvals.sh
        - apply
```

During the execution, script checks if any of approving users are present in `approval-config.yaml` file. It fails (returns error) when none of approving users were allowed by configuration, blocking atlantis workflow (and apply step).

---

## BUILDING

Pull requests are built automatically using https://github.com/getindata/docker-image-template

## IMAGES

Merged pull requests create new release and upload new images automatically. Check changelog for details.

## USAGE

## CONTRIBUTING

Contributions are very welcomed!

Start by reviewing [contribution guide](CONTRIBUTING.md) and our [code of conduct](CODE_OF_CONDUCT.md). After that, start coding and ship your changes by creating a new PR.

## LICENSE

Apache 2 Licensed. See [LICENSE](LICENSE) for full details.

## AUTHORS

<!--- Replace repository name -->
<a href="https://github.com/getindata/docker-atlantis/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=getindata/docker-atlantis" />
</a>

Made with [contrib.rocks](https://contrib.rocks)
