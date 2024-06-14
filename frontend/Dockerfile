# E:\DevOps\ecommerce-django-react\frontend\Dockerfile

# Build the React app
FROM node:14 as build

WORKDIR /app
COPY ./frontend/package.json /app/package.json
RUN npm install
COPY ./frontend /app/
RUN npx browserslist@latest --update-db
RUN npm run build

# Serve the React app with Nginx
FROM nginx:alpine
COPY --from=build /app/build /usr/share/nginx/html
COPY ./frontend/nginx.conf /etc/nginx/nginx.conf
