# Mello's Blog

一个使用 Hugo 和 PaperMod 搭建的个人静态博客，用于长期记录考研、信号与系统、数学、英语、AI、通信、边缘部署和编程项目。

目标是简单、稳定、写作方便、部署省心。项目不包含数据库、后端服务、登录、评论系统或后台管理。

## 项目结构

```text
.
├── archetypes/              # 新文章模板
├── assets/css/extended/     # PaperMod 扩展样式
├── content/                 # Markdown 页面和文章
│   ├── posts/               # 博客文章
│   ├── tags/                # 标签页
│   ├── categories/          # 分类页
│   ├── about.md             # 关于页
│   └── archives.md          # 归档页
├── layouts/_partials/       # KaTeX 数学公式支持与少量主题覆盖
├── static/                  # 静态文件
├── themes/PaperMod/         # PaperMod 主题，使用 git submodule
├── .github/workflows/       # GitHub Pages 自动部署
└── hugo.yaml                # Hugo 站点配置
```

## 本地启动

先安装 Hugo Extended。PaperMod 建议 Hugo 版本不低于 `0.146.0`，本项目的 GitHub Actions 使用 `0.163.1`。

```powershell
hugo version
hugo server -D
```

启动后访问：

```text
http://localhost:1313/
```

如果你是重新克隆仓库，先初始化主题子模块：

```powershell
git submodule update --init --recursive
```

## 新建文章

推荐把文章放在 `content/posts/` 目录：

```powershell
hugo new posts/my-new-note.md
```

然后编辑新生成的 Markdown 文件。常用 front matter 示例：

```yaml
---
title: "文章标题"
date: 2026-06-15T23:59:00+08:00
draft: false
description: "一句话摘要"
categories:
  - 信号与系统
tags:
  - 卷积
  - 专业课
math: true
showToc: true
---
```

需要数学公式时，把 `math` 设为 `true`。支持：

```markdown
行内公式：$y=x+1$

块级公式：
$$
y(t)=\int_{-\infty}^{+\infty}x(\tau)h(t-\tau)d\tau
$$
```

## 本地预览

预览草稿：

```powershell
hugo server -D
```

只看正式文章：

```powershell
hugo server
```

本地构建静态文件：

```powershell
hugo --gc --minify
```

构建结果会生成到 `public/`，这个目录不需要提交到 Git。

## 部署到 GitHub Pages

本项目已经包含 `.github/workflows/hugo.yml`。每次 push 到 `main` 分支，GitHub Actions 会自动构建并部署。

第一次推送到 GitHub：

```powershell
git add .
git commit -m "init hugo blog"
git remote add origin https://github.com/<your-username>/<your-repo>.git
git push -u origin main
```

进入 GitHub 仓库：

1. 打开 `Settings`。
2. 进入 `Pages`。
3. 在 `Build and deployment` 中把 `Source` 设置为 `GitHub Actions`。
4. 回到 `Actions` 页面，等待 `Deploy Hugo site to Pages` 运行完成。

部署后的访问地址通常是：

- 用户主页仓库：`https://<your-username>.github.io/`
- 普通项目仓库：`https://<your-username>.github.io/<your-repo>/`

GitHub Actions 会自动把 Hugo 的 `baseURL` 设置为 Pages 给出的地址。

## 更新主题

PaperMod 使用 git submodule 安装。以后需要更新主题时运行：

```powershell
git submodule update --remote --merge themes/PaperMod
git add .gitmodules themes/PaperMod
git commit -m "chore: update PaperMod theme"
```

## 常见问题

### 本地提示 hugo 不是命令

说明还没有安装 Hugo，或者 Hugo 不在系统 PATH 中。安装 Hugo Extended 后重新打开终端，再运行 `hugo version` 检查。

### 克隆仓库后主题目录是空的

运行：

```powershell
git submodule update --init --recursive
```

### 数学公式没有渲染

检查文章 front matter 里是否有：

```yaml
math: true
```

同时确认公式分隔符写法正确，例如 `$...$` 或 `$$...$$`。

### 新文章本地能看到，部署后看不到

检查文章是否仍然是草稿：

```yaml
draft: false
```

### GitHub Pages 打开是 404

确认仓库 `Settings -> Pages` 的 Source 是 `GitHub Actions`，并确认 Actions 中的部署流程已经成功完成。
