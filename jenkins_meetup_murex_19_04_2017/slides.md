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

 * internal tools manage inter git-project dependencies

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


2.5 K jobs ? developers, i.e. most (if not all) teams, at criteo:

* add/update definition of builds (code review by devtools),

* automate generation of jobs (based on the state of git projects, ...).

---
# Continuous Delivery of jobs
How are jobs updated ?

We need a **job** to create / update *jobs* based on what is in the head of that project.

Unlike [Jenkins + Groovy with the Job DSL plugin](https://www.youtube.com/watch?v=SSK_JaBacE0)
, this **job** is:
* written, using the job DSL plugin,

* goes through the same process as other *jobs*,

* peaks around 45 updates per day,

* thanks (bis) Benoit Perrot :)

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

No kidding, [wat ?](https://www.destroyallsoftware.com/talks/wat)
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


---
# The need of a library of jobs

Once upon a daily, what about:

* using MOAB projects' dependency graph, and

* the list of commits between two builds, to

* identify the commits that broke something and

* send an aggregated report to the author of commits.

Planning meeting:

* we need refactoring.
