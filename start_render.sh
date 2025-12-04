#!/bin/bash
set -e

echo "Iniciando despliegue en Render..."

# Crear directorio para la base de datos si no existe
mkdir -p "$HOME/.simplebot/accounts"

# Codificar el email para usar en rutas
BOTPATH="${ADDR/@/"%40"}"
BOTZIPDB="${ADDR/@/"%40"}.zip"
BOTDB="$HOME/.simplebot/accounts/$BOTPATH/bot.db"

echo "BOTPATH = $BOTPATH"
echo "BOTZIPDB = $BOTZIPDB"
echo "BOTDB = $BOTDB"

# Verificar si el bot ya está inicializado
if [ -f "$BOTDB" ]; then
   echo "✓ Bot ya inicializado!"
else
   echo "→ Restaurando desde backup..."
   
   # Verificar si existe restore.py
   if [ -f "restore.py" ]; then
      python3 ./restore.py
   else
      echo "⚠ No se encontró restore.py, creando uno básico..."
      # Crear un restore.py básico si no existe
      cat > restore.py << 'EOF'
#!/usr/bin/env python3
import os
import sys
import zipfile

def main():
    addr = os.environ.get('ADDR', '')
    if not addr:
        print("ADDR no configurado")
        return
    
    botpath = addr.replace('@', '%40')
    botzip = f"{botpath}.zip"
    
    print(f"Buscando backup: {botzip}")
    
    # Intentar restaurar desde variables de entorno o archivo
    # (En Render no hay persistencia entre reinicios, así que esto es simbólico)
    print("No se encontró backup. Se inicializará desde cero.")
    
if __name__ == '__main__':
    main()
EOF
      python3 ./restore.py
   fi
   
   if [ -f "$BOTZIPDB" ]; then
      echo "✓ Bot restaurado desde backup!"
      rm -f "$BOTZIPDB"
   else
      echo "→ No hay backup disponible, inicializando bot desde cero..."
      
      # Verificar variables requeridas
      if [ -z "$ADDR" ] || [ -z "$PASSWORD" ]; then
         echo "❌ ERROR: ADDR y PASSWORD deben estar configurados"
         exit 1
      fi
      
      # Inicializar bot
      echo "Inicializando bot con email: $ADDR"
      python3 -m simplebot init "$ADDR" "$PASSWORD"
      
      # Agregar plugin telebridge
      if [ -f "telebridge.py" ]; then
         echo "Agregando plugin telebridge.py..."
         python3 -m simplebot --account "$ADDR" plugin --add ./telebridge.py
      elif [ -f "simplebot_tg.py" ]; then
         echo "Agregando plugin simplebot_tg.py..."
         python3 -m simplebot --account "$ADDR" plugin --add ./simplebot_tg.py
      else
         echo "⚠ No se encontró el archivo del plugin"
      fi
      
      echo "✓ Bot inicializado correctamente"
   fi
fi

# Agregar administrador si está configurado
if [ -n "$ADMIN" ]; then
   echo "Agregando administrador: $ADMIN"
   python3 -m simplebot --account "$ADDR" admin --add "$ADMIN"
else
   echo "⚠ ADMIN no configurado - el bot no tendrá administradores"
fi

# Verificar token de Telegram
if [ -z "$TGTOKEN" ]; then
   echo "⚠ TGTOKEN no configurado - algunas funciones pueden no trabajar"
fi

# Iniciar el bot
echo "🚀 Iniciando bot..."
echo "================================"
python3 -m simplebot --account "$ADDR" serve
