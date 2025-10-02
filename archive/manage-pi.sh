#!/bin/bash

show_menu() {
  echo ""
  echo "Gambino Pi Management"
  echo "===================="
  echo "1. Check service status"
  echo "2. View live logs"
  echo "3. Restart service"
  echo "4. Test API connection"
  echo "5. Browse local database"
  echo "6. Update configuration"
  echo "7. System diagnostics"
  echo "8. Exit"
  echo ""
}

while true; do
  show_menu
  read -p "Choose option (1-8): " choice
  
  case $choice in
    1)
      sudo systemctl status gambino-pi
      ;;
    2)
      echo "Press Ctrl+C to exit logs"
      sudo journalctl -u gambino-pi -f
      ;;
    3)
      sudo systemctl restart gambino-pi
      echo "Service restarted"
      ;;
    4)
      cd /opt/gambino-pi
      npm run test-api
      ;;
    5)
      cd /opt/gambino-pi
      npm run browse-db
      ;;
    6)
      nano /opt/gambino-pi/.env
      echo "Configuration updated. Restart service to apply changes."
      ;;
    7)
      echo "System Diagnostics:"
      echo "=================="
      echo "Service status:"
      systemctl is-active gambino-pi
      echo ""
      echo "Serial devices:"
      ls -la /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || echo "No USB serial devices"
      echo ""
      echo "Network connectivity:"
      ping -c 3 api.gambino.gold 2>/dev/null && echo "Internet: OK" || echo "Internet: FAILED"
      echo ""
      echo "Database size:"
      du -h /opt/gambino-pi/data/gambino-pi.db 2>/dev/null || echo "No database file"
      ;;
    8)
      echo "Goodbye!"
      exit 0
      ;;
    *)
      echo "Invalid option"
      ;;
  esac
  
  read -p "Press Enter to continue..."
done
