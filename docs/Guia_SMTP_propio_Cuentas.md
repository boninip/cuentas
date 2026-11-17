# Guía: correo propio (SMTP) para los avisos de Pinto / Cuentas

Estado: PROPUESTA. Lo hacés vos en el panel de Supabase; yo nunca manejo claves ni tokens.
Aplica primero al proyecto de DEV (Pinto Core).

## Por qué
El correo incluido de Supabase es solo para pruebas: tiene un límite muy bajo de envíos por hora y, en proyectos nuevos, solo manda a miembros del equipo. Para que lleguen los mails de ingreso (magic link / código) a cualquier persona, hace falta un SMTP propio.

## Qué necesitás
1. Un dominio tuyo para enviar (cuando esté definida la marca: INPI y dominios siguen pendientes). Hasta entonces, para DEV alcanza con el dominio de prueba del proveedor.
2. Una cuenta en un proveedor de envío transaccional (por ejemplo Resend, Brevo, Postmark o Amazon SES). Cualquiera que ofrezca SMTP sirve.

## Pasos
1. En el proveedor: verificá el dominio remitente y agregá en tu DNS los registros que te pide (SPF y DKIM; si podés, también DMARC).
2. En el proveedor: creá una credencial SMTP. Guardala en tu gestor de contraseñas. No me la pases.
3. Supabase → Authentication → Emails → SMTP Settings → activar "Custom SMTP".
4. Completá: remitente (ej. `avisos@tu-dominio`), nombre del remitente ("Pinto"), host, puerto, usuario y contraseña del proveedor.
5. Supabase → Authentication → Rate Limits: subí el límite de mails por hora a lo que necesites.
6. Supabase → Authentication → URL Configuration: confirmá que el Site URL y las Redirect URLs incluyan https://boninip.github.io/cuentas/ (pendiente de antes: Site URL).
7. Probá: pedí un código de ingreso con un mail que no sea el tuyo y revisá que llegue (mirá también spam).

## Plantillas en español
Supabase → Authentication → Emails → Templates: traducí asunto y texto de "Magic link" / "Confirm signup" al rioplatense, con el nombre Pinto.

## Qué queda fuera
- Notificaciones push: necesitan claves propias (VAPID) y una función de servidor. Siguen pendientes.
- Avisos por mail de cada gasto: no están construidos; hoy los avisos son la lista de actividad dentro de la app.
