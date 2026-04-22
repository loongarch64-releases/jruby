#!/bin/bash
set -euo pipefail

UPSTREAM_OWNER=jruby
UPSTREAM_REPO=jruby
VERSION="${1}"
echo "   🏢 Org:   ${UPSTREAM_OWNER}"
echo "   📦 Proj:  ${UPSTREAM_REPO}"
echo "   🏷️  Ver:   ${VERSION}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DISTS="${ROOT_DIR}/dists"
SRCS="${ROOT_DIR}/srcs"

mkdir -p "${DISTS}/${VERSION}" "${SRCS}"

# ==========================================
# 👇 用户自定义构建逻辑 (示例)
# ==========================================

echo "🔧 Compiling ${UPSTREAM_OWNER}/${UPSTREAM_REPO} ${VERSION}..."

# 1. 准备阶段：安装依赖、下载代码、应用补丁等
prepare()
{
    echo "📦 [Prepare] Setting up build environment..."
    
    [ -d "${SRCS}/${VERSION}" ] && rm -rf "${SRCS}/${VERSION}"
    mkdir -p "${SRCS}/${VERSION}"
    wget -O "${SRCS}/${VERSION}.tar.gz" --quiet --show-progress "https://github.com/${UPSTREAM_OWNER}/${UPSTREAM_REPO}/releases/download/${VERSION}/jruby-src-${VERSION}.tar.gz"
    tar -xzf "${SRCS}/${VERSION}.tar.gz" -C "${SRCS}/${VERSION}" --strip-components=1
    if [[ "${VERSION}" == "10.0.2.0" || "${VERSION}" == "10.0.3.0" ]]; then
	# 这两个版本在制作发布包时拉取离线文档的逻辑会导致版本冲突
        sed -i 's/ruby3.4-doc/ruby3.4-doc_3.4.5/' "${SRCS}/${VERSION}/maven/jruby-dist/pom.rb"
    fi

    echo "✅ [Prepare] Environment ready."
}

# 2. 编译阶段：核心构建命令
build()
{
    echo "🔨 [Build] Compiling source code..."
    
    pushd "${SRCS}/${VERSION}"
    
    ./mvnw clean install -Pdist,complete -DskipTests -Dinvoker.skip=true

    popd

    echo "✅ [Build] Compilation finished."
}

# 3. 后处理阶段：整理产物、清理临时文件、验证版本
post_build()
{
    echo "📦 [Post-Build] Organizing artifacts..."
    
    PRODUCT_ZIP="${DISTS}/${VERSION}/jruby-bin-${VERSION}.zip"
    PRODUCT_TAR="${DISTS}/${VERSION}/jruby-bin-${VERSION}.tar.gz"
    PRODUCT_JAR="${DISTS}/${VERSION}/jruby-complete-${VERSION}.jar"
    DIST_DIR="${SRCS}/${VERSION}/maven/jruby-dist/target"
    COMPLETE_DIR="${SRCS}/${VERSION}/maven/jruby-complete/target"

    cp "${DIST_DIR}/jruby-dist-${VERSION}-bin.zip" "${PRODUCT_ZIP}"
    cp "${DIST_DIR}/jruby-dist-${VERSION}-bin.tar.gz" "${PRODUCT_TAR}"
    cp "${COMPLETE_DIR}/jruby-complete-${VERSION}.jar" "${PRODUCT_JAR}"

    chown -R "${HOST_UID}:${HOST_GID}" "${DISTS}" "${SRCS}"

    echo "✅ [Post-Build] Artifacts ready in ./dists/${VERSION}."
}

# 主入口
main()
{
    prepare
    build
    post_build
}

main

# ==========================================
# 👆 自定义逻辑结束
# ==========================================

cat > "${DISTS}/${VERSION}/release.txt" <<EOF
Project: ${UPSTREAM_REPO}
Organization: ${UPSTREAM_OWNER}
Version: ${VERSION}
Build Time: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

echo "✅ Compilation finished."
ls -lh "${DISTS}/${VERSION}"
