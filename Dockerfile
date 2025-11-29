# -----------------------------------------------------------------
# 阶段一: "node-builder" - 安装 Node.js 和 Puppeteer
# -----------------------------------------------------------------
FROM node:20-slim AS node-builder

# 设置工作目录
WORKDIR /usr/src/app

# 复制 package.json 和 package-lock.json (如果有的话)
COPY package*.json ./

# 安装 puppeteer。Puppeteer 会下载 Chromium，我们用 --no-sandbox 节省空间和避免权限问题
# 使用 PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true 不下载Chromium，因为我们将在后面使用系统自带的
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
RUN npm install puppeteer \
    && npm cache clean --force

# -----------------------------------------------------------------
# 阶段二: "final" - 创建最终的 PHP+Apache 镜像
# -----------------------------------------------------------------
FROM php:8.2-apache-bullseye

# 安装系统依赖和 Node.js
# 1. wget, gnupg, ca-certificates: 用于添加 NodeSource 仓库
# 2. chromium: 浏览器本身，比 puppeteer 下载的更小
# 3. libnss3, libatk1.0-0, etc.: Chromium 运行时需要的库
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    ca-certificates \
    curl \
    software-properties-common \
    unzip \
    chromium \
    libnss3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libgtk-3-0 \
    libgbm1 \
    libasound2 \
    && \
    # 安装 Node.js
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    # 清理缓存以减小镜像大小
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 从 "node-builder" 阶段复制 node_modules 文件夹
# 这样我们就有了 puppeteer，但不需要在最终镜像里重复安装
COPY --from=node-builder /usr/src/app/node_modules /usr/local/lib/node_modules/

# 告令行中的 'node' 命令需要能找到 puppeteer
# 我们创建一个全局符号链接
RUN ln -s /usr/local/lib/node_modules/puppeteer /usr/local/lib/node_modules/puppeteer-core

# 启用 Apache 的 mod_rewrite 模块，用于美化 URL
RUN a2enmod rewrite

# 复制我们的 PHP 文件到 Apache 的网站根目录
COPY index.php /var/www/html/

# 设置正确的权限
RUN chown -R www-data:www-data /var/www/html

# 暴露 80 端口 (Apache 默认端口)
EXPOSE 80
