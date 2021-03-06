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
* |> 2016: [Intel OTC](https://01.org/), Android Continuous Integration
* |> 2017: [Criteo](http://www.criteo.com/), Devtools

## Some links
* [Github](https://github.com/yetanotherion)
* [Linkedin](https://fr.linkedin.com/in/ion-alberdi-787b4a1)


???

Buildbot at Intel, Jenkins permits updating
jobs without rebooting the server natively.

---

# About Criteo

[Real-Time Digital Advertising That Works](http://www.criteo.com)

* 130 countries

* 11K advertisers

* 16K publishers

* Listed on the NASDAQ since October 2013

* 90% retention rate

* R&D = 21% of the workforce

???

Among others, Criteo proud of retention rate

---

# Jenkins @ Criteo

* 2.5 K jobs

--

* 30K executions / day

???

higher than openstack (20K > multimaster), but
these metrics may not be good estimators of the load.

--
* CI/ (part of) CD jobs of

 * applications (csharp, java, scala, python):

 * infrastructure code (chef, ruby)

 * jobs code (jobdsl, groovy)

--
* all jobs written using the [Job DSL Plugin](https://wiki.jenkins-ci.org/display/JENKINS/Job+DSL+Plugin)


---

# Continuous Delivery of jobs

Two (linked) units of trunk based development:

|              | Languages           | #Git repositories |
| ------------ |:-------------------:| -----------------:|
| MOAB         | csharp              |131                |
| JMOAB        | java, scala, python |239                |

How to add gerrit project (git repository) in the JMOAB:
```groovy

import criteo.tools.build.jenkins.dsl.ContinuousIntegration


ContinuousIntegration.jmoabProject {

    gerritProject(<projectName>)
}```

???

MOAB is mother of all builds, not Massive Ordnance Air Blast, nor
Mother of All Bombs.

---

# Continuous Delivery of jobs
Two (linked) units of trunk based development:

|              | Languages           | #Git repositories |
| ------------ |:-------------------:| -----------------:|
| MOAB         | csharp              |131                |
| JMOAB        | java, scala, python |239                |

How to add gerrit project (git repository) in the JMOAB:
```groovy
// Internal extension to the job dsl
import criteo.tools.build.jenkins.dsl.ContinuousIntegration

// Java project (moab, mother of all builds, trunk based development)
ContinuousIntegration.jmoabProject {
    // you got it right, git/gerrit is used as SCM / Code Review
    gerritProject(<projectName>)
}```


---

# Continuous Delivery of jobs

Job descriptions files stored in a git repository, plugged to

* presubmit:

 * peer code review

 * test

* postsubmit: triggers the update of all jobs from the head of the project.

???

* presubmit: job triggered at each new patchset (kind of PR)

* postsubmit: triggered after the merge.

--

2.5 K jobs ? developers, i.e. most (if not all) teams, at Criteo R&D:

* add/update definition of builds (code review by devtools),

* automate generation of jobs (based on the state of git repositories, ...).

---
# Continuous Delivery of jobs

Among others, presubmit provides job's diffs:

![workaround_diff](imgs/workaround_diff.png)

???

Diff most of the information provided after
---
# Continuous Delivery of jobs
How are jobs updated ?

We need a job, let's call it, **refreshJob**, to create *jobs* based on what is in the head of that repository.

--

Unlike [Jenkins + Groovy with the Job DSL plugin](https://www.youtube.com/watch?v=SSK_JaBacE0)
, this **refreshJob**:
* is written, using the job DSL plugin,

* goes through the same process as other *jobs*,

* reaches peaks of around 45 updates per day.

???

* In the video they create the job using the jenkins UI.

* No use of Process Job Dsl step.

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

          xmls.eachWithIndex { file, i ->
                def name = file.baseName
                ...
                def job = instance.getItemByFullName(name)
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

???

Pause to ask their opinion on the result about the meeting.

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
 * said otherwise: *jobs* must be updated right after the merge.

---
# Continuous Delivery of the library

Proposal:

* create a new gerrit project that produces **_libraries_** as [JAR](https://docs.oracle.com/javase/tutorial/deployment/jar/basicsindex.html)

--

* presubmit
 * test
 * peer code review

--

* postsubmit: triggers the same but updated **refreshJob**

--

* *jobs* that need **_libraries_**
 * call [@Grab(group, artifact, version)](http://docs.groovy-lang.org/latest/html/documentation/grape.html) in
 * groovyCommand / systemGroovyCommand
 * getting the version from an environment variable

???
Say grab is something to download a jar and its transitive dependencies
and make it available in the classpath of the groovy runtime.

---
# Continuous Delivery of the library

**refreshJob** is updated to

* compute **_V_**, the version of the library

---
# Continuous Delivery of the library

**refreshJob** is updated to

* compute **_V_**, the version of the library (the number of commits in **master**)

--

* upload the [JAR](https://docs.oracle.com/javase/tutorial/deployment/jar/basicsindex.html)-s to the internal maven repository

--

* compile all *jobs* with the environment variable set to **_V_**.

---
# Continuous Delivery of the library

![release_library_before](imgs/delivery_library_before.svg)

???

Before

---
# Continuous Delivery of the library

![release_library](imgs/delivery_library.svg)

???

After

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

???

joke about the hack

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
???

joke about the hack
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

The code of the helper to grab modules from the library:
```groovy
private static String getServicesLibsVersion() {
	return System.getenv('SERVICES_LIBS_VERSION') ?: '9300'
}

/**
 * Returns a @Grab command.
 * @param module name of the module to grab
 * @param transitive tells if the transitive dependencies should be fetched too.
 * ...
 */
static String grabModule(Module module, boolean transitive) {
	"@Grab(group=\'${group}\', module=\'${module}\',
           version=\'${getServicesLibsVersion()}\',
           transitive=${transitive})"
}```

---
# Continuous Delivery of the library

The code of the job:
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
Some code of the library:

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
}```

---
# Continuous Delivery of the library

A test (among the 167) in the library:

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
# Enabled features (Moab Broken mail)

![moab_broken_mail](imgs/commit_mails.png)


---
# Enabled features (Make -j on jenkins jobs)

Once upon a story:
* one jenkins job per GerritProject,
* a dependency graph between projects,
* schedule jobs to build all projects.

--

How ?
```groovy
GerritProject(A)
├── GerritProject(B)
│   ├── GerritProject(E)
│   └── GerritProject(G)
├── GerritProject(C)
│   └── GerritProject(H)
└── GerritProject(D)
    ├── GerritProject(I)
    └── GerritProject(J)
```

???

Pause to ask their opinion
---
# Enabled features (Make -j on jenkins jobs)

Once upon a story:
* one jenkins job per GerritProject,
* a dependency graph between projects,
* schedule jobs to build all projects.

The sequential way
```groovy
GerritProject(A) *
├── GerritProject(B)
│   ├── GerritProject(E)
│   └── GerritProject(G)
├── GerritProject(C)
│   └── GerritProject(H)
└── GerritProject(D)
    ├── GerritProject(I)
    └── GerritProject(J)
```

---
# Enabled features (Make -j on jenkins jobs)

Once upon a story:
* one jenkins job per GerritProject,
* a dependency graph between projects,
* schedule jobs to build all projects.

The sequential way
```groovy
GerritProject(A)
├── GerritProject(B) *
│   ├── GerritProject(E)
│   └── GerritProject(G)
├── GerritProject(C)
│   └── GerritProject(H)
└── GerritProject(D)
    ├── GerritProject(I)
    └── GerritProject(J)
```

---
# Enabled features (Make -j on jenkins jobs)

Once upon a story:
* one jenkins job per GerritProject,
* a dependency graph between projects,
* schedule jobs to build all projects.

The sequential way
```groovy
GerritProject(A)
├── GerritProject(B)
│   ├── GerritProject(E)
│   └── GerritProject(G)
├── GerritProject(C) *
│   └── GerritProject(H)
└── GerritProject(D)
    ├── GerritProject(I)
    └── GerritProject(J)
```

---
# Enabled features (Make -j on jenkins jobs)

Once upon a story:
* one jenkins job per GerritProject,
* a dependency graph between projects,
* schedule jobs to build all projects.

The sequential way
```groovy
GerritProject(A)
├── GerritProject(B)
│   ├── GerritProject(E) *
│   └── GerritProject(G)
├── GerritProject(C)
│   └── GerritProject(H)
└── GerritProject(D)
    ├── GerritProject(I)
    └── GerritProject(J)
```

---
# Enabled features (Make -j on jenkins jobs)

Once upon a story:
* one jenkins job per GerritProject,
* a dependency graph between projects,
* schedule jobs to build all projects.

The sequential way
```groovy
GerritProject(A)
├── GerritProject(B)
│   ├── GerritProject(E)
│   └── GerritProject(G)
├── GerritProject(C)
│   └── GerritProject(H)
└── GerritProject(D) *
    ├── GerritProject(I)
    └── GerritProject(J)
```

---
# Enabled features (Make -j on jenkins jobs)

Once upon a story:
* one jenkins job per GerritProject,
* a dependency graph between projects,
* schedule jobs to build all projects.

The sequential way
```groovy
GerritProject(A)
├── GerritProject(B)
│   ├── GerritProject(E)
│   └── GerritProject(G)
├── GerritProject(C)
│   └── GerritProject(H)
└── GerritProject(D)
    ├── GerritProject(I) *
    └── GerritProject(J)
```

---
# Enabled features (Make -j on jenkins jobs)

Once upon a story:
* one jenkins job per GerritProject,
* a dependency graph between projects,
* schedule jobs to build all projects.

The sequential way
```groovy
GerritProject(A)
├── GerritProject(B)
│   ├── GerritProject(E)
│   └── GerritProject(G)
├── GerritProject(C)
│   └── GerritProject(H)
└── GerritProject(D)
    ├── GerritProject(I)
    └── GerritProject(J) *
```

---
# Enabled features (Make -j on jenkins jobs)

Once upon a story:
* one jenkins job per GerritProject,
* a dependency graph between projects,
* schedule jobs to build all projects.

The sequential way
```groovy
GerritProject(A)
├── GerritProject(B)
│   ├── GerritProject(E)
│   └── GerritProject(G) *
├── GerritProject(C)
│   └── GerritProject(H)
└── GerritProject(D)
    ├── GerritProject(I)
    └── GerritProject(J)
```

---
# Enabled features (Make -j on jenkins jobs)

Once upon a story:
* one jenkins job per GerritProject,
* a dependency graph between projects,
* schedule jobs to build all projects.

The sequential way
```groovy
GerritProject(A)
├── GerritProject(B)
│   ├── GerritProject(E)
│   └── GerritProject(G)
├── GerritProject(C)
│   └── GerritProject(H) *
└── GerritProject(D)
    ├── GerritProject(I)
    └── GerritProject(J)
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

???

parallel waits for all builds to finish before continuing

---
# Enabled features (Make -j on jenkins jobs)
Some parallelization with the [Jenkins pipeline plugin](https://wiki.jenkins-ci.org/display/JENKINS/Pipeline+Plugin)
```groovy
GerritProject(A) *
├── GerritProject(B)
│   ├── GerritProject(E)
│   └── GerritProject(G)
├── GerritProject(C)
│   └── GerritProject(H)
└── GerritProject(D)
    ├── GerritProject(I)
    └── GerritProject(J)
```


---
# Enabled features (Make -j on jenkins jobs)
Some parallelization with the [Jenkins pipeline plugin](https://wiki.jenkins-ci.org/display/JENKINS/Pipeline+Plugin)
```groovy
GerritProject(A)
├── GerritProject(B) *
│   ├── GerritProject(E)
│   └── GerritProject(G)
├── GerritProject(C) *
│   └── GerritProject(H)
└── GerritProject(D) *
    ├── GerritProject(I)
    └── GerritProject(J)
```

---
# Enabled features (Make -j on jenkins jobs)

Some parallelization with the [Jenkins pipeline plugin](https://wiki.jenkins-ci.org/display/JENKINS/Pipeline+Plugin)
```groovy
GerritProject(A)
├── GerritProject(B)
│   ├── GerritProject(E)
│   └── GerritProject(G)
├── GerritProject(C)
│   └── GerritProject(H)
└── GerritProject(D) *
    ├── GerritProject(I)
    └── GerritProject(J)
```
---
# Enabled features (Make -j on jenkins jobs)

Some parallelization with the [Jenkins pipeline plugin](https://wiki.jenkins-ci.org/display/JENKINS/Pipeline+Plugin)
```groovy
GerritProject(A)
├── GerritProject(B)
│   ├── GerritProject(E) // we could have started E and G
│   └── GerritProject(G)
├── GerritProject(C)
│   └── GerritProject(H) // and H too :S
└── GerritProject(D) *
    ├── GerritProject(I)
    └── GerritProject(J)
```

---
# Enabled features (Make -j on jenkins jobs)

Some parallelization with the library
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

Some parallelization with the library
```groovy
GerritProject(A) *
├── GerritProject(B)
│   ├── GerritProject(E)
│   └── GerritProject(G)
├── GerritProject(C)
│   └── GerritProject(H)
└── GerritProject(D)
    ├── GerritProject(I)
    └── GerritProject(J)
```

---
# Enabled features (Make -j on jenkins jobs)

Some parallelization with the library
```groovy
GerritProject(A)
├── GerritProject(B) *
│   ├── GerritProject(E)
│   └── GerritProject(G)
├── GerritProject(C) *
│   └── GerritProject(H)
└── GerritProject(D) *
    ├── GerritProject(I)
    └── GerritProject(J)
```

---
# Enabled features (Make -j on jenkins jobs)

Some parallelization with the library
```groovy
GerritProject(A)
├── GerritProject(B)
│   ├── GerritProject(E) *
│   └── GerritProject(G) *
├── GerritProject(C) *
│   └── GerritProject(H)
└── GerritProject(D) *
    ├── GerritProject(I)
    └── GerritProject(J)
```

---
# Enabled features (Make -j on jenkins jobs)

Some parallelization with the library
```groovy
GerritProject(A)
├── GerritProject(B)
│   ├── GerritProject(E)
│   └── GerritProject(G) *
├── GerritProject(C)
│   └── GerritProject(H) *
└── GerritProject(D) *
    ├── GerritProject(I)
    └── GerritProject(J)
```

---
# Enabled features (Make -j on jenkins jobs)

Some parallelization with the library
```groovy
GerritProject(A)
├── GerritProject(B)
│   ├── GerritProject(E)
│   └── GerritProject(G) *
├── GerritProject(C)
│   └── GerritProject(H)
└── GerritProject(D)
    ├── GerritProject(I) *
    └── GerritProject(J) *
```

---
# Enabled features (Make -j on jenkins jobs)

Some parallelization with the library
```groovy
GerritProject(A)
├── GerritProject(B)
│   ├── GerritProject(E)
│   └── GerritProject(G)
├── GerritProject(C)
│   └── GerritProject(H)
└── GerritProject(D)
    ├── GerritProject(I) *
    └── GerritProject(J) *
```

---
# Enabled features (Make -j on jenkins jobs)

Some parallelization with the library
```groovy
GerritProject(A)
├── GerritProject(B)
│   ├── GerritProject(E)
│   └── GerritProject(G)
├── GerritProject(C)
│   └── GerritProject(H)
└── GerritProject(D)
    ├── GerritProject(I)
    └── GerritProject(J) *
```

---
# Enabled features (Make -j on jenkins jobs)

Some parallelization with the library
```groovy
GerritProject(A)
├── GerritProject(B)
│   ├── GerritProject(E)
│   └── GerritProject(G)
├── GerritProject(C)
│   └── GerritProject(H)
└── GerritProject(D)
    ├── GerritProject(I)
    └── GerritProject(J)
```

---
# Enabled features

The current state of enabled features (besides the two above):

--
* send MOAB related metrics to [Graphite](https://graphiteapp.org/)

--

* input / output of Moab build with distributed cache

--

* filtering test reports based on dependency graph

--

* compute flaky test reports

--
* the delivery of the library reaches peaks around  20 updates per day

--

* [We are the champions](https://www.youtube.com/watch?v=04854XqcfCY)?

---
# Limitations and next steps

The current state of the **bugs**:

--

* Memory leak when using Groovy as JSR-223 scripting language ([GROOVY-7683](https://issues.apache.org/jira/browse/GROOVY-7683))

???

* Due to a calling a groovy job at the end of each build, need to reboot jenkins

--

 * Groovy 2.4.8 interoperability issues ([JENKINS-42189](https://issues.jenkins-ci.org/browse/JENKINS-42189))

???

* Tried to integrate groovy 2.4.8, failed due to pipeline plugin reimplementing a garbage collector


--

* Share cache with locking ([IVY-654](https://issues.apache.org/jira/browse/IVY-654))

???
* Explain concurrency issues (repository/resolution cache dir: not locked)

--

 * Add an argument to set the resolution cache path in @Grab ([GROOVY-8097](https://issues.apache.org/jira/browse/GROOVY-8097))

???

* Use a resolution cache dir per concurrent job. Not everyone ok with it.

--

* [Don't worry be happy](https://www.youtube.com/watch?v=d-diB65scQU)?

---
# Questions?


Thanks for your attention.

Slides made with [remark](https://github.com/gnab/remark/).
