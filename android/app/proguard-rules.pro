# v1.8.2：保护 file_picker 插件——release 默认开启 R8 混淆，
# 若插件 MethodChannel 相关类被混淆/裁剪，pickFiles/saveFile 会静默失败
# （表现为系统文件选择器弹不出来）。保留插件全部实现类。
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class io.github.mrblobman.** { *; }
