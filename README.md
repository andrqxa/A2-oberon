## Active Object System (AOS aka A2)

Unregistered users can download the A2 system from the repository located at https://svn-dept.inf.ethz.ch/svn/lecturers/a2/trunk using svn (read only access as user "infsvn.anonymous" using password "anonymous")

To checkout the trunk, use
<pre>
svn checkout --username infsvn.anonymous --password anonymous https://svn-dept.inf.ethz.ch/svn/lecturers/a2/trunk aos
</pre>


Please inform us, if you need write-access to the repository, in which case we will set up an account.

## Build Server


~~There is a build server that regularly checks out the repository and builds several systems. Moreover, it runs some checks for the compiler like compilation and execution tests. An overview over the current build results can be found at http://builds.cas.inf.ethz.ch~~

The build server will be replaced by a CICD script. Will be revived as soon as we have made the switch from SVN to GIT.
