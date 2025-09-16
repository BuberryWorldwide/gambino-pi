#!/bin/bash
MAPPING_FILE="/opt/gambino-pi/data/machine-mapping.json"

if [ -f "$MAPPING_FILE" ]; then
    echo "📋 Current Mappings:"
    node -e "
    const mapping = JSON.parse(require('fs').readFileSync('$MAPPING_FILE', 'utf8'));
    Object.entries(mapping.machineMapping || {})
      .sort(([a], [b]) => a.localeCompare(b))
      .forEach(([fledgling, machineId]) => {
        console.log(\`  \${fledgling} → \${machineId}\`);
      });
    "
else
    echo "No mappings found."
fi
