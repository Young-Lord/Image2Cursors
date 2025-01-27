# Image2Cursors

半自动将图片文件转换为 Linux 可用的 xcursors 文件。详细内容请查看`main.py`。

大致流程：

1. 使用 CursorCreate 图形化编辑
2. 编辑完后作为项目导出
3. 编辑`build.json`，加入注释等信息
4. 使用 GIMP 等找到`hotspot`（大致相当于指针作用的那一个像素），手动编辑`build.json`，加入`hotspots_full`（若对精度要求不高，本步可改为在 CursorCreate 中图形化编辑 hotspot）
5. 运行`main.py`，根据 `WARNING`等补充对应图标，或者调节`MANUAL_REFERS_TO_TABLE`以使用现有图标代替缺失图标
6. 生成后的图标将会自动为当前用户安装，可以在 KDE Plasma 6 的 System Settings > Appearance > Colors & Themes > Cursors 应用，并选择合适尺寸。

示例图标来源：[【别当欧尼酱了】真寻自制像素鼠标指针](https://www.bilibili.com/video/BV1FT41127t8)
