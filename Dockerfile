# Изолированная среда агентной разработки для метарепозитория.
# Внутри: PHP 8.4 (сервисы), git, gh, Node 22 + Claude Code.
# Агент видит ТОЛЬКО смонтированную мету — файлов хоста для него не существует.
FROM php:8.4-cli-bookworm

RUN apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends \
      git curl ca-certificates gnupg lsof unzip \
 && mkdir -p /etc/apt/keyrings \
 && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
      | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
      > /etc/apt/sources.list.d/nodesource.list \
 && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends nodejs gh \
 && npm install -g @anthropic-ai/claude-code \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# Не root: у агента нет прав даже внутри контейнера сверх нужного
RUN useradd -m -s /bin/bash agent
USER agent
# каталог кредов заранее и от agent: именованный том унаследует владельца
RUN mkdir -p /home/agent/.claude
WORKDIR /work

COPY --chmod=755 docker/entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["claude"]
