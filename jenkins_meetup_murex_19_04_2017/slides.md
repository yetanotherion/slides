# Continuous Delivery of a (Continuous Integration) library into Jenkins

---

# Agenda

1. Jenkins @ Criteo

2. Continuous Delivery of jobs

3. The need of a library for jobs

4. Continous Delivery of the library

5. Enabled features

6. Limitations and next steps

---

# About me (Ion Alberdi)

## Until now
* 2010: [PhD](https://www.researchgate.net/profile/Ion_Alberdi)
* 2016: Intel OTC, Android Continuous Integration
* 2017: Criteo, devtools

## Some links
* [github](https://github.com/yetanotherion)
* [linkedin](https://github.com/yetanotherion)
* [cv](https://github.com/yetanotherion)

---

# About Criteo

Biggest hadoop-cluster


---

# Jenkins @ Criteo

* 2.5 K jobs

* 30K executions / day

* all jobs written using the [Job DSL Plugin](https://wiki.jenkins-ci.org/display/JENKINS/Job+DSL+Plugin)

* presubmit / postsubmit / (part of) release jobs of

 * applications (csharp, java, scala, python):

 * infrastructure code (chef, ruby)

 * jobs code (jobdsl, groovy)

* two (linked) units of trunk based development:
 * MOAB (chsarp)

 * JMOAB (java, scala, python)

---

# Continuous Delivery of jobs

How to add a java project:
```groovy

import criteo.tools.build.jenkins.dsl.ContinuousIntegration


ContinuousIntegration.jmoabProject {

    gerritProject(<projectName>)
}```

---

# Continuous Delivery of jobs
How to add a java project:

```groovy
// Internal extension to the job dsl (thanks: Benoit Perrot)
import criteo.tools.build.jenkins.dsl.ContinuousIntegration

// Java project (moab, mother of all builds, trunk based development)
ContinuousIntegration.jmoabProject {
    // you got it right, git/gerrit is used as SCM / Code Review
    gerritProject(<projectName>)
}```


---

# Continuous Delivery of jobs

Job descriptions files stored in a git project, plugged to

* presubmit: test and code review needed to merge,

* postsubmit: triggers the update of all jobs from the head of the project.


2.5 K jobs ? developers, i.e. most (if not all) teams, at Criteo R&D:

* add/update definition of builds (code review by devtools),

* automate generation of jobs (based on the state of git projects, ...).

---
# Continuous Delivery of jobs
How are jobs updated ?

We need a **job** to create (update) *jobs* based on what is in the head of that project.

Unlike [Jenkins + Groovy with the Job DSL plugin](https://www.youtube.com/watch?v=SSK_JaBacE0)
, this **job**:
* is written, using the job DSL plugin,

* goes through the same process as other *jobs*,

* has peaks around 45 updates per day,

* thanks (bis) Benoit Perrot.

---
# Continuous Delivery of jobs

```groovy
CriteoJob.job(this, JobNames.refreshBuildConfiguration) {
...
   steps {
     shell("""mvn clean
              mvn compile exec:java // compiles jobs from groovy to xml
           ...""")

     systemGroovyCommand("""...
          import jenkins.model.Jenkins

          xmls.eachWithIndex { file, i ->
                def name = file.baseName
                ...
                def job = Jenkins.instance.getItemByFullName(name)
                if (job) {
                    println "[${i+1}/$count] Updating job $name"
                    job.updateByXml(new StreamSource(stream)) // updates the job
                } else {
                    println "[${i+1}/$count] Creating job $name"
                    instance.createProjectFromXML(name, stream) // creates the job
                }
          }""")
     }
}```

---
# The need of a library of jobs

Once upon a planning meeting, there was a story:

* parse build and test reports,

* send it by mail to the owners of the git repository.


```groovy
with DSLTools.postBuildGroovyScript("""\
import groovy.json.*
@Grab(group='org.yaml', module='snakeyaml', version='1.4')
import org.yaml.snakeyaml.Yaml
${MoabRepoBuildHelper.generateArtifactsForMail('/logs/build-report.json',
                                               '/logs/tests/test-report.json',
                                               pathToFailureReport,
                                               pathToOwners,
                                               pathToRecipients)}"""
```

---
# The need of a library of jobs

...
```groovy
/**
  * @param buildReport path to the build-report.json
  * @param testReport path to the test-report.json
  * @param pathToFailureReport path to the file where the errofs
  *        from buildReport and testReport are aggregated
  * @param pathToRecipients path to the file that contain the recipients
  *        of the <job failed> mail.
  * If at least one build or test failed, pathToRecipients will be populated
  * Else the file will be left as it was.
  */
    static String generateArtifactsForMail(buildReport, testReport,
                                           pathToFailureReport, pathToOwners,
                                           pathToRecipients) {
        return """
             |def failedBuilds = ${computeFailedBuilds(buildReport)}
             |def failedTests = ${computeFailedTests(testReport)}
             |${writeFailureReport('failedBuilds', 'failedTests', pathToFailureReport)}
             |if (!(failedBuilds.empty && failedTests.empty)) {
             |  ${writeOwnersAsRecipients(pathToOwners, pathToRecipients)}
             |}""".stripMargin()
    }
```

---
# The need of a library of jobs

What's the **type** of the returned object ?
```groovy
/**
  * @param buildReport path to the build-report.json
  * @param testReport path to the test-report.json
  * @param pathToFailureReport path to the file where the errofs
  *        from buildReport and testReport are aggregated
  * @param pathToRecipients path to the file that contain the recipients
  *        of the <job failed> mail.
  * If at least one build or test failed, pathToRecipients will be populated
  * Else the file will be left as it was.
  */
    static String generateArtifactsForMail(buildReport, testReport,
                                           pathToFailureReport, pathToOwners,
                                           pathToRecipients) {
        return """
             |def failedBuilds = ${computeFailedBuilds(buildReport)}
             |def failedTests = ${computeFailedTests(testReport)}
             |${writeFailureReport('failedBuilds', 'failedTests', pathToFailureReport)}
             |if (!(failedBuilds.empty && failedTests.empty)) {
             |  ${writeOwnersAsRecipients(pathToOwners, pathToRecipients)}
             |}""".stripMargin()
    }
```

---
# The need of a library of jobs

*String* are you **kidding** ?
```groovy
/**
  * @param buildReport path to the build-report.json
  * @param testReport path to the test-report.json
  * @param pathToFailureReport path to the file where the errofs
  *        from buildReport and testReport are aggregated
  * @param pathToRecipients path to the file that contain the recipients
  *        of the <job failed> mail.
  * If at least one build or test failed, pathToRecipients will be populated
  * Else the file will be left as it was.
  */
    static String generateArtifactsForMail(buildReport, testReport,
                                           pathToFailureReport, pathToOwners,
                                           pathToRecipients) {
        return """
             |def failedBuilds = ${computeFailedBuilds(buildReport)}
             |def failedTests = ${computeFailedTests(testReport)}
             |${writeFailureReport('failedBuilds', 'failedTests', pathToFailureReport)}
             |if (!(failedBuilds.empty && failedTests.empty)) {
             |  ${writeOwnersAsRecipients(pathToOwners, pathToRecipients)}
             |}""".stripMargin()
    }
```


---
# The need of a library of jobs

[WAT?](https://www.destroyallsoftware.com/talks/wat)
```groovy
private static String failedItems(report, successKey, keyToCollect) {
    return """({
        |   def failedItems = []
        |   try {
        |       def o = (Map) ${CbsHelper.readJsonInWorkspace(report)}
        |       if (o) {
        |           failedItems = o['Reports'].findAll { !it['${successKey}'] }
        |                                     .collect { it['${keyToCollect}'] }
        |       }
        |   } catch (Exception x) {
        |       println x
        |   }
        |   return failedItems
        |} ())""".stripMargin()
}

private static String computeFailedTests(testReport) {
    return failedItems(testReport, 'SucceededOrNotRunnable', 'AssemblyName')
}```

---
# The need of a library of jobs

Once upon a daily, what about:

* using MOAB projects' dependency graph, and

* the list of commits between two builds, to

* identify the commits that broke something and

* send an aggregated report to the author of commits.

--

Planning meeting:

--

* we need refactoring.

---
# Continuous Delivery of the library

Requirements:

* Be able to:
 * return something else than **_String_**
 * unit test.

* Without slowing-down the job delivery rate (45 updates per day):
 * said otherwise: jobs must be updated right after the merge.

---
# Continuous Delivery of the library

Proposal:

* create a new git project that produces libraries as [JAR](https://docs.oracle.com/javase/tutorial/deployment/jar/basicsindex.html)

--

* presubmit (test) / postsubmit (triggers the same but updated **job**)

--

* *jobs* that need libraries
 * call [@Grab(group, artifact, version)](http://docs.groovy-lang.org/latest/html/documentation/grape.html) in
 * groovyCommand / systemGroovyCommand
 * getting the version from an environment variable

--

* **job** is updated to
 * compute **_V_**, the version of the library (the number of commits in **master**)
 * upload the jars to the internal maven repository
 * compile all *jobs* with the environment variable set to **_V_**.

---
# Continuous Delivery of the library
```groovy
shell("""\
  cd ${servicesLibsDir}
  # the cleanAndClone above makes the HEAD point to origin/master
  NB_COMMITS=`git rev-list --count HEAD`

  VERSION="\${NB_COMMITS}"
  echo \${VERSION} > version.txt
  if ${Nexus.curlCmdToCheckIfPomArtifactReleased(..., '${VERSION}')}; then
      echo "\${VERSION} was already released. Skipping upload."
  else
      echo "Uploading \${VERSION}."
      ...
      echo "servicesLibsVersion=\${VERSION}" >> gradle.properties
      ${GradleHelper.wrapOnCygwin('./gradlew publish || exit 1')}
      echo "Upload done."
```

---
# Continuous Delivery of the library
```groovy
shell("""\
  cd ${servicesLibsDir}
  # the cleanAndClone above makes the HEAD point to origin/master
  NB_COMMITS=`git rev-list --count HEAD`
  # appending 0. not to conflict with the JMOAB // hack
  VERSION="\${0.NB_COMMITS}"
  echo \${VERSION} > version.txt
  if ${Nexus.curlCmdToCheckIfPomArtifactReleased(..., '${VERSION}')}; then
      echo "\${VERSION} was already released. Skipping upload."
  else
      echo "Uploading \${VERSION}."
      ...
      echo "servicesLibsVersion=\${VERSION}" >> gradle.properties
      ${GradleHelper.wrapOnCygwin('./gradlew publish || exit 1')}
      echo "Upload done."
 ...""")
```

--

```groovy
shell("""\
  mvn clean
  VERSION=`cat ${servicesLibsDir}/version.txt`
  SERVICES_LIBS_VERSION=\${VERSION} mvn compile exec:java
  ...""")
```

---
# Continuous Delivery of the library
The code of the job
```groovy
${ServicesLibsHelper.grabModule(ServicesLibsHelper.Module.CLIENTS, true)}
${ServicesLibsHelper.grabModule(ServicesLibsHelper.Module.MOAB, true)}
...

def moabId = System.getenv('MOAB_ID')
def gm = new GenerateMails(filer,
						   moabId,
						   System.getenv('PREVIOUS_MOAB_ID'),
						   filer.getBuildReportJson(moabId),
						   getRepoBuildJobUrl,
						   new DevtoolsServicesRestClient(),
						   new Gerrit())
def folderPath = Paths.get('${mailsDir}')
def fileFromDev = { dev -> folderPath.resolve(\"mail_\${dev}.mail\") }
Logging.out.println("Generating mails")
gm.writeMailsInFs(fileFromDev)
Logging.out.println("Mails are generated")
...```

---
# Continuous Delivery of the library
It's not a bluff

```groovy
package com.criteo.devtools.moab

import com.criteo.devtools.clients.devtoolsservices.DevtoolsServicesRestClient
import com.criteo.devtools.clients.gerrit.Gerrit
...
/**
 * GenerateMails at the end of C# MOAB pipeline, to report failures.
 */
class GenerateMails extends ProcessMoabRepoBuildResults {
 ...
 def writeMailsInFs(Closure pathFromDev) {
    def mails = generateMailsContent()
    mails.each {
        dev, content ->
     	   Logging.out.println("Generating mail for developer: " + dev)
     	   writeMailInFs(pathFromDev(dev), content)
     	   Logging.out.println("Mail generated")
    }
  }
}
```

---
# Continuous Delivery of the library
It's not a bluff (bis)

```groovy
package com.criteo.devtools.moab

import com.criteo.devtools.clients.devtoolsservices.DevtoolsServicesRestClient
import com.criteo.devtools.clients.gerrit.Gerrit
...

class GenerateMailsTest extends GroovyTestCase {

    void testNominal() {
        def buildReport = toJson(['R1': oneBuildReport(["fstAssembly"], false),
                                  'R2': oneBuildReport(["sndAssembly"], false),
                                  'R3': oneBuildReport(["thirdAssembly"], false)])
        def g = makeGenerateMails(buildReport)
        def expected = ['dev1@company': ['R1': ['broken_repos': ['R1'],
        ....
    }
}
```
