FROM node:20-buster as build


WORKDIR /app


COPY ./frontend/package.json /app/package.json
RUN npm install


COPY ./frontend /app/


RUN npx browserslist@latest --update-db


RUN npm run build


FROM nginx:alpine
COPY --from=build /app/build /usr/share/nginx/html
COPY ./frontend/nginx.conf /etc/nginx/nginx.conf
