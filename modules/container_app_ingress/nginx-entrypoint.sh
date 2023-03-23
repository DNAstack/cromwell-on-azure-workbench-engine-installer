cat <<'EOF' > /etc/nginx/conf.d/default.conf
${nginx_conf}
EOF
nginx -g 'daemon off;'