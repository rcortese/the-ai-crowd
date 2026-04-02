# TODO

- [x] Teste `1`: smoke de precedencia do `PATH` para CLI atualizada pelo usuario.
Contexto: validar que um `npm install -g` feito pelo usuario em `~/.local/share/the-ai-crowd/npm-global` vence o binario seed em `/opt/the-ai-crowd/npm-global-seed`.

- [x] Teste `2`: persistencia do update manual entre recriacoes.
Contexto: validar que a CLI atualizada manualmente continua ativa depois de derrubar e subir o container sem rebuild, por causa do bind mount da `home`.

- [x] Teste `3`: falha precoce do modo Docker-aware sem `DOCKER_GID`.
Contexto: validar que subir com `compose.docker.yaml` sem `DOCKER_GID` falha de forma explicita, em vez de deixar o ambiente entrar quebrado.

- [ ] Teste `5`: healthcheck do modo Docker-aware funcional.
Contexto: validar que, com `DOCKER_ENABLE=true` e `DOCKER_GID` correto, `docker compose version`, acesso ao socket e `docker info` funcionam dentro do container.
