FROM node:24-alpine
WORKDIR /app
COPY --chown=node:node package.json server.mjs state.mjs news.mjs planner.mjs backup.mjs schema.json ./
COPY --chown=node:node public ./public
RUN mkdir /app/data && chown node:node /app/data
USER node
ENV PORT=3055 ABOLIFE_HOST=0.0.0.0 ABOLIFE_DATA_DIR=/app/data
EXPOSE 3055
VOLUME ["/app/data"]
CMD ["node", "server.mjs"]
