/*Base de Datos: Banco*/

/*BLOQUE PRINCIPAL ANONIMO*/
DECLARE
    v_opcion NUMBER:=&opcion;
    v_nombre cliente.nombre%TYPE:=&nombreCliente;
    v_apellidos cliente.apellidos%TYPE:=&apellidosCliente;
    v_posibilidad NUMBER;
    v_posibilidad2 NUMBER;
BEGIN
    v_posibilidad:=Existe_Cliente(v_nombre,v_apellidos);
    v_posibilidad2:=Existe_Cuenta(v_nombre,v_apellidos);
    
    IF v_posibilidad=1 OR v_opcion=3 THEN
        CASE
        WHEN v_opcion=1 THEN
            IF v_posibilidad2=1 THEN
                datos_cliente_con_cuenta(v_nombre,v_apellidos);
            ELSIF v_posibilidad2=-1 THEN
                datos_cliente_sin_cuenta(v_nombre,v_apellidos);
            END IF;
        WHEN v_opcion=2 THEN
            IF v_posibilidad2=1 THEN
                datos_cuentas(v_nombre);
            ELSE
                DBMS_OUTPUT.PUT_LINE('ERROR: EL CLIENTE NO POSEE CUENTAS');
            END IF;
        WHEN v_opcion=3 THEN
            act_interes;
            mostrar_interes;
            ROLLBACK;
        END CASE;
    ELSIF v_posibilidad=-1 THEN
        RAISE_APPLICATION_ERROR(-20001, 'ERROR: CLIENTE NO ENCONTRADO');
    END IF;   
END;
/

-----PROCEDIMIENTOS
/*1.PROCEDIMIENTO: Segun el nombre del cliente, mostrar nombre y apellidos, Nº cuentas que tiene y el saldo total que tiene.
    En caso de no encontrarse, muestra un mensaje*/

CREATE OR REPLACE PROCEDURE datos_cliente_con_cuenta(v_nombreCli cliente.nombre%type,v_apellidoCli cliente.apellidos%type) AS
    
    CURSOR cursor_cliente_datos IS
        select cli.cod_cliente,cli.nombre,cli.apellidos,count(cu.cod_cuenta) as ncuentas,sum(cu.saldo) as saldoT
            from cliente cli,cuenta cu
            where cli.cod_cliente=cu.cod_cliente
            and cli.nombre=v_nombreCli and cli.apellidos=v_apellidoCli
            group by cli.cod_cliente, cli.apellidos, cli.nombre;

    v_datosCli cursor_cliente_datos%rowtype;
BEGIN
    OPEN cursor_cliente_datos;
    FETCH cursor_cliente_datos INTO v_datosCli;
        WHILE cursor_cliente_datos%found LOOP
            DBMS_OUTPUT.PUT_LINE('Codigo Cliente: '||v_datosCli.cod_cliente||' Nombre: '||v_datosCli.nombre||' '||v_datosCli.apellidos||' Nº Cuentas: '||v_datosCli.ncuentas ||' Saldo total: '||v_datosCli.saldoT);
    FETCH cursor_cliente_datos into v_datosCli;
    END LOOP;
    CLOSE cursor_cliente_datos;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20002, 'ERROR DESCONOCIDO');
END;
/

--2.PROCEDIMIENTO: Muestra por cada cuenta del cliente pasado por parametros, los gastos e ingresos y el periodo en que se hayan realizado movimientos 
CREATE OR REPLACE PROCEDURE datos_cuentas(v_nombre cliente.nombre%type) AS
    
    CURSOR cursor_cuentas_cliente IS
        select cu.cod_cuenta
        from cuenta cu,cliente cli
        where cli.nombre=v_nombre
        and cu.cod_cliente=cli.cod_cliente;
        
    v_datosCu cursor_cuentas_cliente%rowtype;
    v_gastos movimiento.importe%type;
    v_ingresos movimiento.importe%type;

    CURSOR cursor_periodo_mov(v_codCuenta cuenta.cod_cuenta%type) IS
        select cu.cod_cuenta,min(m.fecha_hora) as minDate,max(m.fecha_hora) as maxDate
        from cuenta cu,movimiento m
        where cu.cod_cuenta=v_codCuenta
        and m.cod_cuenta=cu.cod_cuenta 
        group by cu.cod_cuenta;
    v_datosMov cursor_periodo_mov%rowtype;

BEGIN
    OPEN cursor_cuentas_cliente;
    FETCH cursor_cuentas_cliente INTO v_datosCu;
        WHILE cursor_cuentas_cliente%found LOOP 
        FETCH cursor_cuentas_cliente INTO v_datosCu;
            v_gastos:=Cuenta_Gastos(v_datosCu.cod_cuenta);
            v_ingresos:=Cuenta_Ingresos(v_datosCu.cod_cuenta);
            
            IF v_gastos IS NULL OR v_ingresos IS NULL THEN
            DBMS_OUTPUT.PUT_LINE('CODIGO CUENTA: '||v_datosCu.cod_cuenta||CHR(10)||
                                    'NO EXISTEN MOVIMIENTOS PARA ESTA CUENTA'
                                    ||CHR(10)||'#########################');
            ELSE
                FOR v_datosMov IN cursor_periodo_mov(v_datosCu.cod_cuenta) LOOP
                DBMS_OUTPUT.PUT_LINE('CODIGO CUENTA: '||v_datosCu.cod_cuenta||CHR(10)||
                                        'INGRESOS: '||trim(to_char(v_ingresos,'999G990D99L'))||' GASTOS: '||trim(to_char(v_gastos,'999G990D99L'))
                                        ||CHR(10)||
                                        'PERIODO: '||v_datosMov.minDate||'-'||v_datosMov.maxDate
                                        ||CHR(10)||'#########################');
                END LOOP;
            END IF;
        END LOOP;
    CLOSE cursor_cuentas_cliente;
END;
/

--3.PROCEDIMIENTO: Muestra los datos de los clientes sin cuenta
CREATE OR REPLACE PROCEDURE datos_cliente_sin_cuenta(v_nombreCli cliente.nombre%type,v_apellidoCli cliente.apellidos%type) AS
    
    CURSOR cursor_cliente_datos_sin_cuenta IS
        SELECT cod_cliente,nombre,apellidos,direccion
        FROM cliente 
        WHERE nombre=v_nombreCli and apellidos=v_apellidoCli;
        
    v_datosCliSin cursor_cliente_datos_sin_cuenta%rowtype;
BEGIN
    OPEN cursor_cliente_datos_sin_cuenta;
    FETCH cursor_cliente_datos_sin_cuenta INTO v_datosCliSin;
        WHILE cursor_cliente_datos_sin_cuenta%found LOOP
            DBMS_OUTPUT.PUT_LINE('Codigo Cliente: '||v_datosCliSin.cod_cliente||' Nombre: '||v_datosCliSin.nombre||' '||v_datosCliSin.apellidos||' Direccion: '||v_datosCliSin.direccion);
    FETCH cursor_cliente_datos_sin_cuenta into v_datosCliSin;
    END LOOP;
    CLOSE cursor_cliente_datos_sin_cuenta;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20002, 'ERROR DESCONOCIDO');
END;
/
--4.PROCEDIMIENTO:  Sube un 25 % el interes de aquellas cuentas cuyo saldo este por encima de la media

CREATE OR REPLACE PROCEDURE act_interes AS
    CURSOR cursor_interes_cuenta IS
        select cod_cuenta,saldo,to_char(interes ,'0D99') as interes
        from cuenta 
        where saldo>(select trunc(avg(saldo),2) from cuenta) for update;
    
    v_datosInt cursor_interes_cuenta%rowtype;

BEGIN
    DBMS_OUTPUT.PUT_LINE('#####################################'||CHR(10)||'SIN ACTUALIZACIÓN');
    OPEN cursor_interes_cuenta;
    FETCH cursor_interes_cuenta INTO v_datosInt;
    WHILE cursor_interes_cuenta%found LOOP
        UPDATE cuenta SET interes=interes+0.25
        WHERE CURRENT OF cursor_interes_cuenta;
            dbms_output.put_line('CODIGO CUENTA: '||v_datosInt.cod_cuenta||CHR(10)||'       SALDO: '|| TRIM(to_char(v_datosInt.saldo,'999g999d99l'))|| ' INTERES: '||v_datosInt.interes);
    FETCH cursor_interes_cuenta INTO v_datosInt;
    END LOOP;
    CLOSE cursor_interes_cuenta;
    DBMS_OUTPUT.PUT_LINE('#####################################');
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20004,'ERROR DESCONOCIDO');
END;
/

--5.PROCEDIMIENTO : Mostrar interes actualizado
CREATE OR REPLACE PROCEDURE mostrar_interes AS
    CURSOR cursor_interes IS
        select cod_cuenta, saldo,to_char(interes ,'0D99') as interes
        from cuenta 
        where saldo>(select trunc(avg(saldo),2) from cuenta);
    v_datosInC cursor_interes%rowtype;

BEGIN
    DBMS_OUTPUT.PUT_LINE('###########################################'||CHR(10)||'ACTUALIZACIÓN');
    FOR registro IN cursor_interes LOOP
        DBMS_OUTPUT.PUT_LINE('CODIGO CUENTA: '||registro.cod_cuenta||CHR(10)||'     SALDO:'||TRIM(to_char(registro.saldo,'999g999d99l'))|| ' INTERES ACTUALIZADO: '||registro.interes);
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('###########################################'||CHR(10));

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20004,'ERROR DESCONOCIDO');
END;
/

--FUNCIONES
--1.FUNCION: Sacar el total de ingresos de una cuenta determinada
CREATE OR REPLACE FUNCTION Cuenta_Ingresos(v_cuenta movimiento.cod_cuenta%type) RETURN NUMBER AS
    v_ingresos movimiento.importe%type;
BEGIN
    select sum(importe) into v_ingresos
    from movimiento m,tipo_movimiento tp
    where tp.salida='No'
    and m.cod_cuenta=v_cuenta
    and tp.cod_tipo_movimiento = m.cod_tipo_movimiento;

RETURN v_ingresos;
END;
/
--2.FUNCION: Sacar el total de gastos de una cuenta determinada

CREATE OR REPLACE FUNCTION Cuenta_Gastos(v_cuenta movimiento.cod_cuenta%type) RETURN NUMBER AS
    v_gastos movimiento.importe%type;
BEGIN
    select sum(importe) into v_gastos
    from movimiento m,tipo_movimiento tp
    where tp.salida='Sí'
    and m.cod_cuenta=v_cuenta
    and tp.cod_tipo_movimiento = m.cod_tipo_movimiento;

    RETURN v_gastos;
END;
/
--3.FUNCION: Comprueba de que el cliente pasado por parametro exista en la BBDD

CREATE OR REPLACE FUNCTION Existe_Cliente(v_nombre cliente.nombre%type,v_apellidos cliente.apellidos%type) RETURN NUMBER AS
    v_existe NUMBER;
BEGIN
    select count(nombre) into v_existe
    from cliente 
    where nombre=v_nombre and apellidos=v_apellidos;
    
    IF v_existe>0 THEN
        RETURN 1;
    ELSIF v_existe=0 THEN
        RETURN -1;
    END IF;
END;
/

--4.FUNCION: Comprueba si el cliente posee cuentas    
 
CREATE OR REPLACE FUNCTION Existe_Cuenta(v_nombre cliente.nombre%type,v_apellidos cliente.apellidos%type) RETURN NUMBER AS
    v_existe NUMBER;
BEGIN
    select count(cu.cod_cuenta) into v_existe
    from cuenta cu, cliente cli
    where cli.nombre=v_nombre and cli.apellidos=v_apellidos
    and cli.cod_cliente=cu.cod_cliente;

    IF v_existe<>0 then 
        RETURN 1;
    ELSIF v_existe=0 THEN
        RETURN -1;
    END IF;
END;
/

---DISPARADORES

--1.DIPARADOR DE FILA: AUDITORIA CONTROL DE CLIENTES

CREATE TABLE Auditoria_Cliente(
    ACCION VARCHAR2(100),
    FECHA DATE,
    USUARIO VARCHAR2(100)
);

CREATE OR REPLACE TRIGGER AUDITORIA_CLIENTE
    BEFORE INSERT OR DELETE OR UPDATE ON cliente FOR EACH ROW
DECLARE
    v_accion VARCHAR2(100);
BEGIN
    IF inserting THEN
        v_accion:='INSERTADO';    
    ELSIF updating THEN
        v_accion:='ACTUALIZADO';
    END IF;
    
    INSERT INTO Auditoria_Cliente (ACCION,FECHA,USUARIO) VALUES(v_accion,sysdate,user);
    
END AUDITORIA_CLIENTE;
/  

--2.DISPARADOR DE FILA: Actualiza automáticamente el Cod_sucursal de cuenta, cuando se actualiza el cod_sucursal de sucursal

CREATE OR REPLACE TRIGGER actualizar_sucursal
    AFTER UPDATE OF cod_sucursal ON sucursal FOR EACH ROW
BEGIN
    UPDATE cuenta SET cod_sucursal=:NEW.cod_sucursal WHERE cod_sucursal=:OLD.cod_sucursal;
END;
/

--3.DISPARADOR DE FILA: No permite insertar cuentas con un saldo mayor al maximo actual.
CREATE OR REPLACE TRIGGER control_cuentas_saldo
    BEFORE INSERT OR UPDATE OF saldo ON cuenta FOR EACH ROW
    
DECLARE
    v_saldoMax NUMBER(10,2);
BEGIN
    SELECT MAX(saldo) INTO v_saldoMax FROM cuenta;
    IF :NEW.saldo >v_saldoMax THEN
        DBMS_OUTPUT.PUT_LINE('saldo nuevo > saldo actual');
        RAISE_APPLICATION_ERROR(-20004,'ERROR: SALDO EXCESIVO');
    END IF;
END;
/

--4.DISPARADOR DE INSTRUCCION: Permite insertar clientes en un horario determinado

CREATE OR REPLACE TRIGGER control_insertado_clientes
    BEFORE INSERT ON cliente
BEGIN
    IF ( to_char(SYSDATE,'HH24')) NOT IN ('17','18','19') THEN
        RAISE_APPLICATION_ERROR (-20003,'ERROR: Sólo se puede añadir personal entre las 10 y las 12:59');
    END IF;
END;
/
