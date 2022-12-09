## Active Object System (AOS aka A2) git repository (from 9.12.2022)

In order to run A2 on your Windows- or Linux-based system, clone this repository and unzip the appropriate binary within the repository. Example (Linux, AMD64):
```
git clone https://gitlab.inf.ethz.ch/felixf/oberon.git
cd oberon
unzip Linux64
Linux64/a2.sh
```
Note that in order to keep size of the repository reasonable, we do not commmit binary files directly into the git repository. Instead, we use the large file storage (LFS) support of gitlab in order to keep these files out of local git storage of your computer. 

If you cannot or do not want to install LFS for git, you need to download the corresponding zip file from this gitlab website because then git is downloading only a stub of the files. You can identify this with file sizes: if the zip files in the root directory of this project are a few bytes small, then you do not have lfs installed.

Please inform me, if you need developer-access to the repository, if you observe missing files, or if you, in general, want to help setting this up.

## Active Object System (AOS aka A2) SVN repository (before 9.12.2022)

Unregistered users can download the A2 system from the repository located at https://svn-dept.inf.ethz.ch/svn/lecturers/a2/trunk using svn (read only access as user "infsvn.anonymous" using password "anonymous")

To checkout the trunk, use
<pre>
svn checkout --username infsvn.anonymous --password anonymous https://svn-dept.inf.ethz.ch/svn/lecturers/a2/trunk aos
</pre>

## Build Server

The previously existing build-server is being replaced by the CI/CD pipeline in this gitlab. Currently, the pipeline builds the binaries for each commit in a zip file. The zip-files comprise the most-recent binaries and can be downloaded from the pipeline artifacts. More tests will follow. 
