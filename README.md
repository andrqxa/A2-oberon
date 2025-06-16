# Active Object System (AOS aka A2)

## History

The Active Object System (AOS), also known as A2, is a programming language and runtime system designed for concurrent and distributed computing. It was developed at ETH Zurich and has been used in various research projects and educational settings.
Historically, it was holded in the SVN repository at https://svn-dept.inf.ethz.ch/svn/lecturers/a2/trunk, but since December 9, 2022, it has been migrated to a GitLab repository.

### Active Object System (AOS aka A2) SVN repository (before 9.12.2022)

Unregistered users can download the A2 system from the repository located at https://svn-dept.inf.ethz.ch/svn/lecturers/a2/trunk using svn (read only access as user "infsvn.anonymous" using password "anonymous")

To checkout the trunk, use
<pre>
svn checkout --username infsvn.anonymous --password anonymous https://svn-dept.inf.ethz.ch/svn/lecturers/a2/trunk aos
</pre>

## Active Object System (AOS aka A2) git repository (from 9.12.2022)

To run A2 on your Windows or Linux system, please clone this repository and refer to the [Task-based Build System](#task-based-build-system) of the README.

Note that, to keep the repository size manageable, we use GitLab's Large File Storage (LFS) to store large files outside your local Git repository.

If you cannot or prefer not to install Git LFS, you need to manually download the corresponding ZIP files from the GitLab project page. Without LFS, Git will only download placeholder files. You can identify this by their size: if the ZIP files in the root directory of the project are only a few bytes in size, LFS is not installed.

Most of the ZIP files requiring LFS are located in the `data` directory.

Please let me know if you need developer access to the repository, encounter any missing files, or would like assistance with the setup.

**Do not use a directory name that contains a dash (-). It is recommended to name the folder A2oberon**

---

## Working with Git LFS

To properly clone the repository and download the required large files:

```bash
sudo apt install git-lfs
git lfs install
git clone https://gitlab.inf.ethz.ch/felixf/oberon.git A2oberon
cd A2oberon
git lfs pull
```

## Build Server

The previously existing build-server is being replaced by the CI/CD pipeline in this gitlab. Currently, the pipeline builds the binaries for each commit in a zip file. The zip-files comprise the most-recent binaries and can be downloaded from the pipeline artifacts. More tests will follow.

---

## Active Object System (AOS aka A2) Git repository (from 9.12.2022)

In order to run A2 on your Windows- or Linux-based system, clone this repository and unzip the appropriate binary within the repository. Example (Linux, AMD64):

```bash
git clone https://gitlab.inf.ethz.ch/felixf/oberon.git
cd oberon
unzip Linux64
Linux64/a2.sh
```

Note that in order to keep size of the repository reasonable, we do not commit binary files directly into the git repository. Instead, we use the large file storage (LFS) support of GitLab in order to keep these files out of local git storage of your computer.

If you cannot or do not want to install LFS for Git, you need to download the corresponding zip file from this GitLab website because then Git is downloading only a stub of the files. You can identify this with file sizes: if the zip files in the root directory of this project are a few bytes small, then you do not have LFS installed.

Please inform me if you need developer access to the repository, if you observe missing files, or if you want to help setting this up.

---

## Task-based Build System

This project uses [Taskfile.dev](https://taskfile.dev) as its cross-platform task runner.
It provides a modern alternative to Makefiles with cleaner syntax and modularity.

### Installation of `task`

**Linux/macOS:**

```bash
sudo sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin
```

**Windows (using Scoop):**

```powershell
scoop install go-task
```

Or download precompiled binary from: [https://github.com/go-task/task/releases](https://github.com/go-task/task/releases)

---

### How to Use

Most commonly used command:

```bash
task
```

This will run the default task, which builds all supported platforms.

You can list all available tasks:

```bash
task --list
```

To execute a specific task:

```bash
task <task-name>
```

Example:

```bash
task oberon
```

---

### Key Tasks Overview

| Task                    | Description                                                |
| ----------------------- | ---------------------------------------------------------- |
| `oberon`                | Build and replace host compiler (for `{{.HOST}}` platform) |
| `modules`               | Generate list of `.Mod` files as environment variable      |
| `compile-all-modules`   | Compile all modules using `compile-module` task            |
| `build-platform`        | Build the full compiler binary for a given platform        |
| `platforms`             | Build compiler for all supported platforms                 |
| `clean`                 | Remove all build artifacts                                 |
| `clean-temporary-files` | Clean intermediate build files                             |
| `set-platform-env`      | Prepare environment variables for current build target     |

---

### Testing

To run test modules:

```bash
task test
```

---

### Cleaning Up

To clean up all build artifacts:

```bash
task clean
```

To remove only temporary files:

```bash
task clean-temporary-files
```

---