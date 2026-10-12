import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

allprojects {
    repositories {
        // 定制构建：Flutter 引擎构件国内镜像（io.flutter:flutter_embedding_*）
        maven("https://storage.flutter-io.cn/download.flutter.io")
        // 定制构建：优先使用阿里云镜像（官方源在构建环境不可达）
        maven("https://maven.aliyun.com/repository/google")
        maven("https://maven.aliyun.com/repository/central")
        maven("https://maven.aliyun.com/repository/public")
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    afterEvaluate {
        if (project.extensions.findByName("android") != null) {
            val androidExtension =
                project.extensions.getByName("android") as com.android.build.gradle.BaseExtension

            if (androidExtension.namespace == null) {
                androidExtension.namespace = project.group.toString()
            }

            androidExtension.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }

            project.tasks.withType<KotlinCompile>().configureEach {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                }
            }

            val pluginCompileSdkStr = androidExtension.compileSdkVersion
            val pluginCompileSdk = pluginCompileSdkStr
                ?.removePrefix("android-")
                ?.toIntOrNull()
            if (pluginCompileSdk != null && pluginCompileSdk < 36) {
                project.logger.error(
                    "Warning: Overriding compileSdk version in Flutter plugin: ${project.name} " +
                            "from $pluginCompileSdk to 36 (to work around https://issuetracker.google.com/issues/199180389).\n" +
                            "If there is not a new version of ${project.name}, consider filing an issue against ${project.name} " +
                            "to increase their compileSdk to the latest (otherwise try updating to the latest version)."
                )
                androidExtension.setCompileSdkVersion(36)
            }
        }

        project.buildDir = File(rootProject.buildDir, project.name)
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

// 定制构建环境：全局禁用 Lint（8G 内存下是主要 OOM 来源，且打包不需要）
allprojects {
    tasks.matching {
        it.name.startsWith("lint") || it.name.contains("Lint")
    }.configureEach {
        enabled = false
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
