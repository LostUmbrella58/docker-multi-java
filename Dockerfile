# 多阶段构建：从官方Azul Zulu镜像中提取JDK
FROM azul/zulu-openjdk:8-latest as java8
FROM azul/zulu-openjdk:11-latest as java11  
FROM azul/zulu-openjdk:17-latest as java17
FROM azul/zulu-openjdk:21-latest as java21
FROM azul/zulu-openjdk:24-latest as java24
FROM azul/zulu-openjdk:25-latest as java25

# 最终镜像
FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

# 设置时区
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# 从官方Azul镜像中复制JDK到标准路径
COPY --from=java8 /usr/lib/jvm/zulu8 /usr/lib/jvm/zulujdk-8
COPY --from=java11 /usr/lib/jvm/zulu11 /usr/lib/jvm/zulujdk-11
COPY --from=java17 /usr/lib/jvm/zulu17 /usr/lib/jvm/zulujdk-17
COPY --from=java21 /usr/lib/jvm/zulu21 /usr/lib/jvm/zulujdk-21
COPY --from=java24 /usr/lib/jvm/zulu24 /usr/lib/jvm/zulujdk-24
COPY --from=java25 /usr/lib/jvm/zulu25 /usr/lib/jvm/zulujdk-25

# 验证复制的JDK
RUN echo "🔍 验证从官方镜像复制的JDK..." && \
    for v in 8 11 17 21 24 25; do \
        if [ -d "/usr/lib/jvm/zulujdk-$v" ]; then \
            echo "检验 Java $v..." && \
            /usr/lib/jvm/zulujdk-$v/bin/java -version 2>&1 | head -1 && \
            echo "✅ Java $v 正常"; \
        else \
            echo "❌ Java $v 目录不存在"; \
        fi; \
    done

# 使用 update-alternatives 管理Java版本
RUN update-alternatives --install /usr/bin/java java /usr/lib/jvm/zulujdk-8/bin/java 80 && \
    update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/zulujdk-8/bin/javac 80 && \
    update-alternatives --install /usr/bin/java java /usr/lib/jvm/zulujdk-11/bin/java 110 && \
    update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/zulujdk-11/bin/javac 110 && \
    update-alternatives --install /usr/bin/java java /usr/lib/jvm/zulujdk-17/bin/java 170 && \
    update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/zulujdk-17/bin/javac 170 && \
    update-alternatives --install /usr/bin/java java /usr/lib/jvm/zulujdk-21/bin/java 210 && \
    update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/zulujdk-21/bin/javac 210 && \
    update-alternatives --install /usr/bin/java java /usr/lib/jvm/zulujdk-24/bin/java 240 && \
    update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/zulujdk-24/bin/javac 240 && \
    update-alternatives --install /usr/bin/java java /usr/lib/jvm/zulujdk-25/bin/java 250 && \
    update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/zulujdk-25/bin/javac 250 && \
    update-alternatives --set java /usr/lib/jvm/zulujdk-17/bin/java && \
    update-alternatives --set javac /usr/lib/jvm/zulujdk-17/bin/javac

# 创建Java版本切换脚本
RUN echo '#!/bin/bash' > /usr/bin/java-change && \
    echo 'if [ -z "$1" ]; then echo "用法: java-change {8|11|17|21|24|25}"; echo "当前Java版本:"; java -version; exit 1; fi' >> /usr/bin/java-change && \
    echo 'if [ ! -d "/usr/lib/jvm/zulujdk-$1" ]; then echo "❌ Java $1 未安装"; exit 1; fi' >> /usr/bin/java-change && \
    echo 'update-alternatives --set java /usr/lib/jvm/zulujdk-$1/bin/java && update-alternatives --set javac /usr/lib/jvm/zulujdk-$1/bin/javac' >> /usr/bin/java-change && \
    echo 'echo "✅ Java 已切换至版本 $1"' >> /usr/bin/java-change && \
    echo 'java -version 2>&1 | head -1' >> /usr/bin/java-change && \
    chmod +x /usr/bin/java-change

# 创建各版本直接命令
RUN for v in 8 11 17 21 24 25; do \
        if [ -d "/usr/lib/jvm/zulujdk-$v" ]; then \
            printf '#!/bin/bash\nexec /usr/lib/jvm/zulujdk-%s/bin/java "$@"\n' "$v" > /usr/bin/java"$v"; \
            chmod +x /usr/bin/java"$v"; \
        fi; \
    done

# 创建版本列表脚本
RUN echo '#!/bin/bash' > /usr/bin/java-list && \
    echo 'echo "📦 可用Java版本:"' >> /usr/bin/java-list && \
    echo 'for v in 8 11 17 21 24 25; do' >> /usr/bin/java-list && \
    echo '  if [ -d "/usr/lib/jvm/zulujdk-$v" ]; then' >> /usr/bin/java-list && \
    echo '    version_info=$(/usr/lib/jvm/zulujdk-$v/bin/java -version 2>&1 | head -1 | cut -d"\"" -f2)' >> /usr/bin/java-list && \
    echo '    current_java=$(readlink -f /usr/bin/java)' >> /usr/bin/java-list && \
    echo '    if [[ "$current_java" == *"zulujdk-$v"* ]]; then' >> /usr/bin/java-list && \
    echo '      echo "  ✅ Java $v ($version_info) - 当前版本"' >> /usr/bin/java-list && \
    echo '    else' >> /usr/bin/java-list && \
    echo '      echo "  📦 Java $v ($version_info)"' >> /usr/bin/java-list && \
    echo '    fi' >> /usr/bin/java-list && \
    echo '  fi' >> /usr/bin/java-list && \
    echo 'done' >> /usr/bin/java-list && \
    echo 'echo ""' >> /usr/bin/java-list && \
    echo 'echo "💡 使用: java-change <版本> 或 java<版本> -version"' >> /usr/bin/java-list && \
    chmod +x /usr/bin/java-list

# 设置默认JAVA_HOME环境变量
ENV JAVA_HOME=/usr/lib/jvm/zulujdk-17

WORKDIR /app
CMD ["bash"]