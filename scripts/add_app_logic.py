import sys
import yaml
import os
import shutil
from datetime import datetime

def process_app(app_path, url_path, server_host):
    compose_file = os.path.join(app_path, "docker-compose.yml")
    
    if not os.path.exists(compose_file):
        print(f"Error: {compose_file} not found")
        sys.exit(1)

    # Backup
    backup = f"{compose_file}.backup.{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    shutil.copy2(compose_file, backup)
    print(f"Backup created: {backup}")

    with open(compose_file, 'r') as f:
        data = yaml.safe_load(f)

    if 'services' not in data:
        print("Error: No 'services' in docker-compose.yml")
        sys.exit(1)

    # Detect main service
    # Prefer service named 'web' or 'app', otherwise first one
    service_name = None
    for name in ['web', 'app', 'frontend', 'server']:
        if name in data['services']:
            service_name = name
            break
    if not service_name:
        service_name = list(data['services'].keys())[0]

    print(f"Target service: {service_name}")
    service = data['services'][service_name]

    # Detect port
    port = 80
    if 'ports' in service:
        for p in service['ports']:
            # Handle "80:80", "80", 80 formats
            p_str = str(p)
            if ':' in p_str:
                try:
                    port = int(p_str.split(':')[1])
                    break
                except:
                    pass
            elif p_str.isdigit():
                port = int(p_str)
                break
    
    print(f"Detected port: {port}")

    # Ensure labels is a list
    if 'labels' not in service:
        service['labels'] = []
    
    if isinstance(service['labels'], dict):
        service['labels'] = [f"{k}={v}" for k,v in service['labels'].items()]
    
    # Remove existing Traefik labels
    service['labels'] = [l for l in service['labels'] if not l.startswith('traefik.')]

    # Add Traefik labels
    router_name = os.path.basename(app_path).replace('_', '-').replace('.', '-')
    
    # For SPAs: Strip prefix so app receives / instead of /consult
    # IMPORTANT: Apps must be built with the correct base path:
    # - Vite: set base: '/consult' in vite.config.js
    # - React (CRA): set homepage: '/consult' in package.json
    # - Vue CLI: set publicPath: '/consult' in vue.config.js
    host_rule_prefix = f"Host(`{server_host}`) && " if server_host else ""
    traefik_labels = [
        "traefik.enable=true",
        # Main router - handles all paths under the URL path
        f"traefik.http.routers.{router_name}.rule={host_rule_prefix}PathPrefix(`{url_path}`)",
        f"traefik.http.routers.{router_name}.entrypoints=web",
        f"traefik.http.services.{router_name}.loadbalancer.server.port={port}",
        # Strip prefix middleware - removes the URL path prefix before forwarding to app
        f"traefik.http.middlewares.{router_name}-stripprefix.stripprefix.prefixes={url_path}",
        f"traefik.http.routers.{router_name}.middlewares={router_name}-stripprefix",
    ]

    print(f"DEBUG: Adding labels: {traefik_labels}")
    service['labels'].extend(traefik_labels)

    # Add network
    if 'networks' not in service:
        service['networks'] = []
    
    # Handle list vs dict networks
    if isinstance(service['networks'], list):
        if 'web' not in service['networks']:
            service['networks'].append('web')
    elif isinstance(service['networks'], dict):
        if 'web' not in service['networks']:
             service['networks']['web'] = {}

    # Root networks
    if 'networks' not in data:
        data['networks'] = {}
    
    if 'web' not in data['networks']:
        data['networks']['web'] = {'external': True}

    with open(compose_file, 'w') as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False)

    print("Success: Configuration updated")
    try:
        update_registry(app_path, url_path, server_host)
    except:
        pass

def update_registry(app_path, url_path, server_host):
    registry_file = "/home/munaim/docker-infrastructure/config/apps.json"
    app_name = os.path.basename(app_path)
    
    try:
        registry = {'apps': []}
        if os.path.exists(registry_file):
            with open(registry_file, 'r') as f:
                try:
                    registry = yaml.safe_load(f) or {'apps': []}
                except:
                    pass
        
        if 'apps' not in registry:
            registry['apps'] = []

        # Remove existing
        registry['apps'] = [a for a in registry.get('apps', []) if a['name'] != app_name]
        
        url_host = server_host or "localhost"
        registry['apps'].append({
            'name': app_name,
            'path': app_path,
            'url': f"http://{url_host}{url_path}",
            'url_path': url_path,
            'added': datetime.now().isoformat()
        })
        registry['last_updated'] = datetime.now().isoformat()

        import json
        with open(registry_file, 'w') as f:
            json.dump(registry, f, indent=2)
            
    except Exception as e:
        print(f"Registry warning: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: python3 add_app_logic.py <app_path> <url_path> <server_host>")
        sys.exit(1)
    
    process_app(sys.argv[1], sys.argv[2], sys.argv[3])
