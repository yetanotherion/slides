# Continuous Delivery of a (Continuous Integration) library into Jenkins

---

# Agenda

1. Jenkins @ Criteo

--

2. Continuous Delivery of jobs

--

3. The need of a library for jobs

--

4. Continous Delivery of the library

--

5. Enabled features

--

6. Limitations and next steps

---

# About me (Ion Alberdi)

## Until now
* 2010: [PhD](https://www.researchgate.net/profile/Ion_Alberdi)
* |> 2016: [Intel OTC](https://01.org/), Android Continuous Integration
* |> 2017: [Criteo](http://www.criteo.com/), devtools

## Some links
* [github](https://github.com/yetanotherion)
* [linkedin](https://github.com/yetanotherion)
* [cv](https://github.com/yetanotherion)

---

# About Criteo

Biggest hadoop-cluster of europe


---

# Jenkins @ Criteo

* 2.5 K jobs

* 30K executions / day

* CI/ (part of) CD jobs of

 * applications (csharp, java, scala, python):

 * infrastructure code (chef, ruby)

 * jobs code (jobdsl, groovy)

* all jobs written using the [Job DSL Plugin](https://wiki.jenkins-ci.org/display/JENKINS/Job+DSL+Plugin)



<!-- * MOAB (chsarp, 131 git repositories)

 * JMOAB (java, scala, python, 239 git repositories)-->

---

# Continuous Delivery of jobs

Two (linked) units of trunk based development:

|              | Languages           | #git projects |
| ------------ |:-------------------:| -------------:|
| MOAB         | csharp              |131            |
| JMOAB        | java, scala, python |239            |

How to add project in the JMOAB:
```groovy

import criteo.tools.build.jenkins.dsl.ContinuousIntegration


ContinuousIntegration.jmoabProject {

    gerritProject(<projectName>)
}```

---

# Continuous Delivery of jobs
Two (linked) units of trunk based development:

|              | Languages           | #git projects |
| ------------ |:-------------------:| -------------:|
| MOAB         | csharp              |131            |
| JMOAB        | java, scala, python |239            |

How to add project in the JMOAB:
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

* presubmit:

 * peer code review

 * test

* postsubmit: triggers the update of all jobs from the head of the project.


2.5 K jobs ? developers, i.e. most (if not all) teams, at Criteo R&D:

* add/update definition of builds (code review by devtools),

* automate generation of jobs (based on the state of git projects, ...).

---
# Continuous Delivery of jobs
How are jobs updated ?

We need a **job** to create *jobs* based on what is in the head of that project.

Unlike [Jenkins + Groovy with the Job DSL plugin](https://www.youtube.com/watch?v=SSK_JaBacE0)
, this **job**:
* is written, using the job DSL plugin,

* goes through the same process as other *jobs*,

* has peaks around 45 updates per day,

* Thanks (bis) Benoit Perrot !

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

--

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

*String*
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

Are you **kidding** ?
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

* create a new git project that produces **_libraries_** as [JAR](https://docs.oracle.com/javase/tutorial/deployment/jar/basicsindex.html)

--

* presubmit
 * test
 * peer code review

--

* postsubmit: triggers the same but updated **job**

--

* *jobs* that need **_libraries_**
 * call [@Grab(group, artifact, version)](http://docs.groovy-lang.org/latest/html/documentation/grape.html) in
 * groovyCommand / systemGroovyCommand
 * getting the version from an environment variable

---
# Continuous Delivery of the library

**job** is updated to

* compute **_V_**, the version of the library (the number of commits in **master**)

* upload the [JAR](https://docs.oracle.com/javase/tutorial/deployment/jar/basicsindex.html)-s to the internal maven repository

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
Some code of the library

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
Some test in the library

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

---
# Enabled features (Broken Moab mail)

![moab_broken_mail](http://localhost:8000/imgs/commit_mails.png) <!-- .element width="50%" -->


---
# Enabled features (Make -j on jenkins jobs)

Once upon a story:
* one jenkins job to build/test a GitProject
* a dependency graph between projects
* schedule jobs to build all projects.

--

How ?
```groovy
GitProject(A)
├── GitProject(B)
│   ├── GitProject(E)
│   └── GitProject(G)
├── GitProject(C)
│   └── GitProject(H)
└── GitProject(D)
    ├── GitProject(I)
    └── GitProject(J)
```

---
# Enabled features (Make -j on jenkins jobs)

Once upon a story:
* one jenkins job to build/test a GitProject
* a dependency graph between projects
* schedule jobs to build all projects.

The sequential way
```groovy
GitProject(A) *
├── GitProject(B)
│   ├── GitProject(E)
│   └── GitProject(G)
├── GitProject(C)
│   └── GitProject(H)
└── GitProject(D)
    ├── GitProject(I)
    └── GitProject(J)
```

---
# Enabled features (Make -j on jenkins jobs)

Once upon a story:
* one jenkins job to build/test a GitProject
* a dependency graph between projects
* schedule jobs to build all projects.

The sequential way
```groovy
GitProject(A)
├── GitProject(B) *
│   ├── GitProject(E)
│   └── GitProject(G)
├── GitProject(C)
│   └── GitProject(H)
└── GitProject(D)
    ├── GitProject(I)
    └── GitProject(J)
```

---
# Enabled features (Make -j on jenkins jobs)

Once upon a story:
* one jenkins job to build/test a GitProject
* a dependency graph between projects
* schedule jobs to build all projects.

The sequential way
```groovy
GitProject(A)
├── GitProject(B)
│   ├── GitProject(E)
│   └── GitProject(G)
├── GitProject(C) *
│   └── GitProject(H)
└── GitProject(D)
    ├── GitProject(I)
    └── GitProject(J)
```

---
# Enabled features (Make -j on jenkins jobs)

Once upon a story:
* one jenkins job to build/test a GitProject
* a dependency graph between projects
* schedule jobs to build all projects.

The sequential way
```groovy
GitProject(A)
├── GitProject(B)
│   ├── GitProject(E) *
│   └── GitProject(G)
├── GitProject(C)
│   └── GitProject(H)
└── GitProject(D)
    ├── GitProject(I)
    └── GitProject(J)
```

---
# Enabled features (Make -j on jenkins jobs)

Once upon a story:
* one jenkins job to build/test a GitProject
* a dependency graph between projects
* schedule jobs to build all projects.

The sequential way
```groovy
GitProject(A)
├── GitProject(B)
│   ├── GitProject(E)
│   └── GitProject(G)
├── GitProject(C)
│   └── GitProject(H)
└── GitProject(D) *
    ├── GitProject(I)
    └── GitProject(J)
```

---
# Enabled features (Make -j on jenkins jobs)

Once upon a story:
* one jenkins job to build/test a GitProject
* a dependency graph between projects
* schedule jobs to build all projects.

The sequential way
```groovy
GitProject(A)
├── GitProject(B)
│   ├── GitProject(E)
│   └── GitProject(G)
├── GitProject(C)
│   └── GitProject(H)
└── GitProject(D)
    ├── GitProject(I) *
    └── GitProject(J)
```

---
# Enabled features (Make -j on jenkins jobs)

Once upon a story:
* one jenkins job to build/test a GitProject
* a dependency graph between projects
* schedule jobs to build all projects.

The sequential way
```groovy
GitProject(A)
├── GitProject(B)
│   ├── GitProject(E)
│   └── GitProject(G)
├── GitProject(C)
│   └── GitProject(H)
└── GitProject(D)
    ├── GitProject(I)
    └── GitProject(J) *
```

---
# Enabled features (Make -j on jenkins jobs)

Once upon a story:
* one jenkins job to build/test a GitProject
* a dependency graph between projects
* schedule jobs to build all projects.

The sequential way
```groovy
GitProject(A)
├── GitProject(B)
│   ├── GitProject(E)
│   └── GitProject(G) *
├── GitProject(C)
│   └── GitProject(H)
└── GitProject(D)
    ├── GitProject(I)
    └── GitProject(J)
```

---
# Enabled features (Make -j on jenkins jobs)

Once upon a story:
* one jenkins job to build/test a GitProject
* a dependency graph between projects
* schedule jobs to build all projects.

The sequential way
```groovy
GitProject(A)
├── GitProject(B)
│   ├── GitProject(E)
│   └── GitProject(G)
├── GitProject(C)
│   └── GitProject(H) *
└── GitProject(D)
    ├── GitProject(I)
    └── GitProject(J)
```

---
# Enabled features (Make -j on jenkins jobs)
Some parallelization with the [Jenkins pipeline plugin](https://wiki.jenkins-ci.org/display/JENKINS/Pipeline+Plugin)
```groovy
def stages = sortProjectsByDepth(projectsByName)
stages.eachWithIndex { stage, i ->
     out.println("# Stage \${i}")
     out.println(stage)

     def builds = stage
         ...
         .collectEntries { x ->
             [ (x.projectName) : { ignore(ABORTED) { build(x.<jobName>,
                                                           MOAB_ID: MOAB_ID) } } ]
         }

     results.putAll(parallel(builds))
}
```

---
# Enabled features (Make -j on jenkins jobs)
Some parallelization with the [Jenkins pipeline plugin](https://wiki.jenkins-ci.org/display/JENKINS/Pipeline+Plugin)
```groovy
GitProject(A) *
├── GitProject(B)
│   ├── GitProject(E)
│   └── GitProject(G)
├── GitProject(C)
│   └── GitProject(H)
└── GitProject(D)
    ├── GitProject(I)
    └── GitProject(J)
```


---
# Enabled features (Make -j on jenkins jobs)
Some parallelization with the [Jenkins pipeline plugin](https://wiki.jenkins-ci.org/display/JENKINS/Pipeline+Plugin)
```groovy
GitProject(A)
├── GitProject(B)
│   ├── GitProject(E)
│   └── GitProject(G)
├── GitProject(C) *
│   └── GitProject(H)
└── GitProject(D) *
    ├── GitProject(I)
    └── GitProject(J)
```

---
# Enabled features (Make -j on jenkins jobs)

Some parallelization with the [Jenkins pipeline plugin](https://wiki.jenkins-ci.org/display/JENKINS/Pipeline+Plugin)
```groovy
GitProject(A)
├── GitProject(B)
│   ├── GitProject(E)
│   └── GitProject(G)
├── GitProject(C)
│   └── GitProject(H)
└── GitProject(D) *
    ├── GitProject(I)
    └── GitProject(J)
```
---
# Enabled features (Make -j on jenkins jobs)

Some parallelization with the [Jenkins pipeline plugin](https://wiki.jenkins-ci.org/display/JENKINS/Pipeline+Plugin)
```groovy
GitProject(A)
├── GitProject(B)
│   ├── GitProject(E) // we could have started E and G :S
│   └── GitProject(G)
├── GitProject(C)
│   └── GitProject(H)
└── GitProject(D) *
    ├── GitProject(I)
    └── GitProject(J)
```

---
# Enabled features (Make -j on jenkins jobs)

Some parallelization with the library (thanks Xavier Noelle)
```groovy
private CompletableFuture<Void> scheduleRemainingJobs(
        DependencyGraph dependencyGraph, Cause cause, String moabId) {
    Collection<BuildExecutionState> newSchedules = scheduleBuildableRepositories(
            dependencyGraph, cause, moabId)

    allOfFutureCollection(newSchedules.collect { schedule ->
        schedule.resultFuture.thenCompose(new Function<BuildExecutionResult,
                                          CompletableFuture<Void>>() {
            @Override
            CompletableFuture<Void> apply(BuildExecutionResult result) {
                builtRepositories[schedule.name] = result

                Logging.out.printf("Built %d/%d repositories\n",
                        builtRepositories.size(),
                        dependencyGraph.repositories.size())

                goingDown ? CompletableFuture.completedFuture(null)
                        : scheduleRemainingJobs(dependencyGraph, cause, moabId)
            }
        })
    })
}```

---
# Enabled features (Make -j on jenkins jobs)

Some parallelization with the library (thanks Xavier Noelle)
```groovy
GitProject(A) *
├── GitProject(B)
│   ├── GitProject(E)
│   └── GitProject(G)
├── GitProject(C)
│   └── GitProject(H)
└── GitProject(D)
    ├── GitProject(I)
    └── GitProject(J)
```

---
# Enabled features (Make -j on jenkins jobs)

Some parallelization with the library (thanks Xavier Noelle)
```groovy
GitProject(A)
├── GitProject(B)
│   ├── GitProject(E)
│   └── GitProject(G)
├── GitProject(C) *
│   └── GitProject(H)
└── GitProject(D) *
    ├── GitProject(I)
    └── GitProject(J)
```

---
# Enabled features (Make -j on jenkins jobs)

Some parallelization with the library (thanks Xavier Noelle)
```groovy
GitProject(A)
├── GitProject(B)
│   ├── GitProject(E) *
│   └── GitProject(G) *
├── GitProject(C)
│   └── GitProject(H)
└── GitProject(D) *
    ├── GitProject(I)
    └── GitProject(J)
```

---
# Enabled features (Make -j on jenkins jobs)

Some parallelization with the library (thanks Xavier Noelle)
```groovy
GitProject(A)
├── GitProject(B)
│   ├── GitProject(E)
│   └── GitProject(G) *
├── GitProject(C)
│   └── GitProject(H)
└── GitProject(D) *
    ├── GitProject(I)
    └── GitProject(J)
```

---
# Enabled features (Make -j on jenkins jobs)

Some parallelization with the library (thanks Xavier Noelle)
```groovy
GitProject(A)
├── GitProject(B)
│   ├── GitProject(E)
│   └── GitProject(G) *
├── GitProject(C)
│   └── GitProject(H)
└── GitProject(D)
    ├── GitProject(I) *
    └── GitProject(J) *
```

---
# Enabled features (Make -j on jenkins jobs)

Some parallelization with the library (thanks Xavier Noelle)
```groovy
GitProject(A)
├── GitProject(B)
│   ├── GitProject(E)
│   └── GitProject(G)
├── GitProject(C)
│   └── GitProject(H)
└── GitProject(D)
    ├── GitProject(I) *
    └── GitProject(J) *
```

---
# Enabled features (Make -j on jenkins jobs)

Some parallelization with the library (thanks Xavier Noelle)
```groovy
GitProject(A)
├── GitProject(B)
│   ├── GitProject(E)
│   └── GitProject(G)
├── GitProject(C)
│   └── GitProject(H)
└── GitProject(D)
    ├── GitProject(I)
    └── GitProject(J) *
```

---
# Enabled features (Make -j on jenkins jobs)

Some parallelization with the library (thanks Xavier Noelle)
```groovy
GitProject(A)
├── GitProject(B)
│   ├── GitProject(E)
│   └── GitProject(G)
├── GitProject(C)
│   └── GitProject(H)
└── GitProject(D)
    ├── GitProject(I)
    └── GitProject(J)
```

---
# Enabled features

The current state of enabled features:

--
* send job related metrics to [Graphite](https://graphiteapp.org/) (Thanks Emmanuel Debanne)

--

* input / output of csharp build with distributed cache (Thanks Patrick Bruneton)

--

* filtering test reports based on dependency graph (Thanks Olivier Tharan)

--

* compute flaky test reports (Thanks Clement Boone)

--
* the delivery of the library reaches peaks around  20 updates per day

--

* [We are the champions](https://www.youtube.com/watch?v=04854XqcfCY)?

---
# Limitations and next steps

The current state of the **bugs**:

--

* [GROOVY-7683](https://issues.apache.org/jira/browse/GROOVY-7683): Memory leak when using Groovy as JSR-223 scripting language

--

* [JENKINS-42189](https://issues.jenkins-ci.org/browse/JENKINS-42189): Groovy 2.4.8 interoperability issues

--

* [IVY-654](https://issues.apache.org/jira/browse/IVY-654): Share cache with locking

--
 ```groovy
 // download transitive dependencies
 ${ServicesLibsHelper.grabModule(ServicesLibsHelper.Module.CLIENTS, true)}
 ${ServicesLibsHelper.grabModule(ServicesLibsHelper.Module.MOAB, true)}
 ```

---
# Limitations and next steps

The current state of the **bugs**:

* [GROOVY-7683](https://issues.apache.org/jira/browse/GROOVY-7683): Memory leak when using Groovy as JSR-223 scripting language


* [JENKINS-42189](https://issues.jenkins-ci.org/browse/JENKINS-42189): Groovy 2.4.8 interoperability issues


* [IVY-654](https://issues.apache.org/jira/browse/IVY-654): Share cache with locking

 * workaround
 ```groovy
 // do not download transitive dependencies
 ${ServicesLibsHelper.grabModule(ServicesLibsHelper.Module.CLIENTS, false)}
 ${ServicesLibsHelper.grabModule(ServicesLibsHelper.Module.MOAB, false)}
 ```

---
# Limitations and next steps

The current state of the **bugs**:

* [GROOVY-7683](https://issues.apache.org/jira/browse/GROOVY-7683): Memory leak when using Groovy as JSR-223 scripting language

* [JENKINS-42189](https://issues.jenkins-ci.org/browse/JENKINS-42189): Groovy 2.4.8 interoperability issues

* [IVY-654](https://issues.apache.org/jira/browse/IVY-654): Share cache with locking

 * workaround
 ```groovy
 // do not download transitive dependencies
 ${ServicesLibsHelper.grabModule(ServicesLibsHelper.Module.CLIENTS, false)}
 ${ServicesLibsHelper.grabModule(ServicesLibsHelper.Module.MOAB, false)}
```


* [GROOVY-8097](https://issues.apache.org/jira/browse/GROOVY-8097) Add an argument to set the resolution cache path in @Grab

--

* ...

---
# Limitations and next steps

The current state of the **bugs**:

* [GROOVY-7683](https://issues.apache.org/jira/browse/GROOVY-7683): Memory leak when using Groovy as JSR-223 scripting language

* [JENKINS-42189](https://issues.jenkins-ci.org/browse/JENKINS-42189): Groovy 2.4.8 interoperability issues

* [IVY-654](https://issues.apache.org/jira/browse/IVY-654): Share cache with locking

 * workaround
 ```groovy
 // do not download transitive dependencies
 ${ServicesLibsHelper.grabModule(ServicesLibsHelper.Module.CLIENTS, false)}
 ${ServicesLibsHelper.grabModule(ServicesLibsHelper.Module.MOAB, false)}
```


* [GROOVY-8097](https://issues.apache.org/jira/browse/GROOVY-8097) Add an argument to set the resolution cache path in @Grab

* [Don't worry be happy](https://www.youtube.com/watch?v=d-diB65scQU)?

---
# Questions?

Thanks for your attention.
