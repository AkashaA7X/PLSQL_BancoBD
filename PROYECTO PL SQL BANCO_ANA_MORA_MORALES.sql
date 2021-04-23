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
            if v_posibilidad2=1 then
            datos_cliente_con_cuenta(v_nombre,v_apellidos);
            elsif v_posibilidad2=-1 then
            datos_cliente_sin_cuenta(v_nombre,v_apellidos);
            end if;
        WHEN v_opcion=2 THEN
            if v_posibilidad2=1 then
                datos_cuentas(v_nombre);
            else
                DBMS_OUTPUT.PUT_LINE('ERROR: EL CLIENTE NO POSEE CUENTAS');
            end if;
        when v_opcion=3 then
            act_interes;
            mostrar_interes;
            rollback;
        END CASE;
    ELSIF v_posibilidad=-1 then
    RAISE_APPLICATION_ERROR(-20001, 'ERROR: CLIENTE NO ENCONTRADO');
    END IF;   
END;
/

-----PROCEDIMIENTOS
/*1.PROCEDIMIENTO: Segun el nombre del cliente, mostrar nombre y apellidos, Nº cuentas que tiene y el saldo total que tiene.
    En caso de no encontrarse, muestra un mensaje*/

create or replace procedure datos_cliente_con_cuenta(v_nombreCli cliente.nombre%type,v_apellidoCli cliente.apellidos%type)
as
cursor cursor_cliente_datos is
    select cli.cod_cliente,cli.nombre,cli.apellidos,count(cu.cod_cuenta) as ncuentas,sum(cu.saldo) as saldoT
    from cliente cli,cuenta cu
    where cli.cod_cliente=cu.cod_cliente
    and cli.nombre=v_nombreCli and cli.apellidos=v_apellidoCli
    group by cli.cod_cliente, cli.apellidos, cli.nombre;

v_datosCli cursor_cliente_datos%rowtype;
begin
    open cursor_cliente_datos;
    fetch cursor_cliente_datos into v_datosCli;
        while cursor_cliente_datos%found loop
            DBMS_OUTPUT.PUT_LINE('Codigo Cliente: '||v_datosCli.cod_cliente||' Nombre: '||v_datosCli.nombre||' '||v_datosCli.apellidos||' Nº Cuentas: '||v_datosCli.ncuentas ||' Saldo total: '||v_datosCli.saldoT);
    fetch cursor_cliente_datos into v_datosCli;
    end loop;
    close cursor_cliente_datos;
    
    exception
    when others then
    RAISE_APPLICATION_ERROR(-20002, 'ERROR DESCONOCIDO');
end;
/
--2.PROCEDIMIENTO: Muestra por cada cuenta del cliente pasado por parametros, los gastos e ingresos y el periodo en que se hayan realizado movimientos 
create or replace procedure datos_cuentas(v_nombre cliente.nombre%type)
as
cursor cursor_cuentas_cliente is
    select cu.cod_cuenta
    from cuenta cu,cliente cli
    where cli.nombre=v_nombre
    and cu.cod_cliente=cli.cod_cliente;
v_datosCu cursor_cuentas_cliente%rowtype;
v_gastos movimiento.importe%type;
v_ingresos movimiento.importe%type;

cursor cursor_periodo_mov(v_codCuenta cuenta.cod_cuenta%type) is
    select cu.cod_cuenta,min(m.fecha_hora) as minDate,max(m.fecha_hora) as maxDate
    from cuenta cu,movimiento m
    where cu.cod_cuenta=v_codCuenta
    and m.cod_cuenta=cu.cod_cuenta 
    group by cu.cod_cuenta;
v_datosMov cursor_periodo_mov%rowtype;

begin
    open cursor_cuentas_cliente;
    fetch cursor_cuentas_cliente into v_datosCu;
        while cursor_cuentas_cliente%found loop 
        fetch cursor_cuentas_cliente into v_datosCu;
            v_gastos:=Cuenta_Gastos(v_datosCu.cod_cuenta);
            v_ingresos:=Cuenta_Ingresos(v_datosCu.cod_cuenta);
            
            if v_gastos is null OR v_ingresos is null then
            DBMS_OUTPUT.PUT_LINE('CODIGO CUENTA: '||v_datosCu.cod_cuenta||CHR(10)||
                                    'NO EXISTEN MOVIMIENTOS PARA ESTA CUENTA'
                                    ||CHR(10)||'#########################');
            else
                for v_datosMov in cursor_periodo_mov(v_datosCu.cod_cuenta) loop
                DBMS_OUTPUT.PUT_LINE('CODIGO CUENTA: '||v_datosCu.cod_cuenta||CHR(10)||
                                        'INGRESOS: '||Cuenta_Ingresos(v_datosCu.cod_cuenta)||' GASTOS: '||Cuenta_Gastos(v_datosCu.cod_cuenta)
                                        ||CHR(10)||
                                        'PERIODO: '||v_datosMov.minDate||'-'||v_datosMov.maxDate
                                        ||CHR(10)||'#########################');
                end loop;
            end if;
        end loop;
end;
/

--3.PROCEDIMIENTO: Muestra los datos de los clientes sin cuenta
create or replace procedure datos_cliente_sin_cuenta(v_nombreCli cliente.nombre%type,v_apellidoCli cliente.apellidos%type)
as
cursor cursor_cliente_datos_sin_cuenta is
    select cod_cliente,nombre,apellidos,direccion
    from cliente 
    where nombre=v_nombreCli and apellidos=v_apellidoCli;
    
v_datosCliSin cursor_cliente_datos_sin_cuenta%rowtype;
begin
    open cursor_cliente_datos_sin_cuenta;
    fetch cursor_cliente_datos_sin_cuenta into v_datosCliSin;
        while cursor_cliente_datos_sin_cuenta%found loop
            DBMS_OUTPUT.PUT_LINE('Codigo Cliente: '||v_datosCliSin.cod_cliente||' Nombre: '||v_datosCliSin.nombre||' '||v_datosCliSin.apellidos||' Direccion: '||v_datosCliSin.direccion);
    fetch cursor_cliente_datos_sin_cuenta into v_datosCliSin;
    end loop;
    close cursor_cliente_datos_sin_cuenta;
    
    exception
    when others then
    RAISE_APPLICATION_ERROR(-20002, 'ERROR DESCONOCIDO');
end;
/
--4.PROCEDIMIENTO:  Sube un 25 % el interes de aquellas cuentas cuyo saldo este por encima de la media

create or replace procedure act_interes
as
cursor cursor_interes_cuenta is
    select cod_cuenta, to_char(saldo,'999g999d99l')as saldo,interes
    from cuenta 
    where saldo>(select trunc(avg(saldo),2) from cuenta)for update;
v_datosInt cursor_interes_cuenta%rowtype;

begin
    dbms_output.put_line('#####################################'||CHR(10)||'SIN ACTUALIZACIÓN');
    open cursor_interes_cuenta;
    fetch cursor_interes_cuenta into v_datosInt;
    while cursor_interes_cuenta%found loop
        update cuenta set interes=interes+0.25
        where current of cursor_interes_cuenta;
        dbms_output.put_line('CODIGO CUENTA: '||v_datosInt.cod_cuenta||CHR(10)||'SALDO:'||v_datosInt.saldo|| ' INTERES: '||v_datosInt.interes);
    fetch cursor_interes_cuenta into v_datosInt;
    end loop;
    close cursor_interes_cuenta;
    dbms_output.put_line('#####################################');
end;
/

--5.PROCEDIMIENTO : Mostrar interes actualizado
create or replace procedure mostrar_interes
as
cursor cursor_interes is
    select cod_cuenta, to_char(saldo,'999g999d99l')as saldo,interes
    from cuenta 
    where saldo>(select trunc(avg(saldo),2) from cuenta);
v_datosInC cursor_interes%rowtype;

begin
    dbms_output.put_line('###########################################'||CHR(10)||'ACTUALIZACIÓN');
    for registro in cursor_interes loop
    dbms_output.put_line('CODIGO CUENTA: '||registro.cod_cuenta||CHR(10)||'SALDO:'||registro.saldo|| ' INTERES ACTUALIZADO: '||registro.interes);
    end loop;
    dbms_output.put_line('###########################################'||CHR(10));
end;
/


--FUNCIONES
--1.FUNCION: Sacar el total de ingresos de una cuenta determinada
create or replace function Cuenta_Ingresos(v_cuenta movimiento.cod_cuenta%type)
return number
as
v_ingresos movimiento.importe%type;
begin
    select sum(importe) into v_ingresos
    from movimiento m,tipo_movimiento tp
    where tp.salida='No'
    and m.cod_cuenta=v_cuenta
    and tp.cod_tipo_movimiento = m.cod_tipo_movimiento;

return v_ingresos;
end;
/
--2.FUNCION: Sacar el total de gastos de una cuenta determinada
create or replace function Cuenta_Gastos(v_cuenta movimiento.cod_cuenta%type)
return number
as
v_gastos movimiento.importe%type;
begin
    select sum(importe) into v_gastos
    from movimiento m,tipo_movimiento tp
    where tp.salida='Sí'
    and m.cod_cuenta=v_cuenta
    and tp.cod_tipo_movimiento = m.cod_tipo_movimiento;

return v_gastos;
end;
/
--3.FUNCION: Comprueba de que el cliente pasado por parametro exista en la BBDD
create or replace function Existe_Cliente(v_nombre cliente.nombre%type,v_apellidos cliente.apellidos%type)
return number
as
v_existe number;
begin
    select count(nombre) into v_existe
    from cliente 
    where nombre=v_nombre and apellidos=v_apellidos;
    if v_existe>0 then
        return 1;
    elsif v_existe=0 then
        return -1;
    end if;
end;
/

--4.FUNCION: Comprueba si el cliente posee cuentas    
 
create or replace function Existe_Cuenta(v_nombre cliente.nombre%type,v_apellidos cliente.apellidos%type)
return number
as
v_existe number;
begin
    select count(cu.cod_cuenta) into v_existe
    from cuenta cu, cliente cli
    where cli.nombre=v_nombre and cli.apellidos=v_apellidos
    and cli.cod_cliente=cu.cod_cliente;

    if v_existe<>0 then 
        return 1;
    elsif v_existe=0 then
        return -1;
    end if;
end;
/

---DISPARADORES

--1.DIPARADOR DE FILA: AUDITORIA CONTROL DE CLIENTES

create table Auditoria_Cliente(
    ACCION varchar2(100),
    FECHA DATE,
    USUARIO varchar2(100)
);

create or replace trigger AUDITORIA_CLIENTE
    before insert or delete or update on cliente for each row
DECLARE
v_accion varchar2(100);
BEGIN
    if inserting then
        v_accion:='INSERTADO';    
    elsif updating then
        v_accion:='ACTUALIZADO';
    end if;
    INSERT INTO Auditoria_Cliente (ACCION,FECHA,USUARIO) VALUES(v_accion,sysdate,user);
end AUDITORIA_CLIENTE;
/  

--2.DISPARADOR DE FILA: Actualiza automáticamente el Cod_sucursal de cuenta, cuando se actualiza el cod_sucursal de sucursal

create or replace trigger actualizar_sucursal
    after update of cod_sucursal on sucursal for each row
begin
    update cuenta set cod_sucursal=:new.cod_sucursal where cod_sucursal=:OLD.cod_sucursal;
end;
/

--3.DISPARADOR DE FILA: No permite insertar cuentas con un saldo mayor al maximo actual.
create or replace trigger control_cuentas_saldo
    before insert or update of saldo on cuenta for each row
declare
v_saldoMax number(10,2);
begin
    select max(saldo) into v_saldoMax from cuenta;
    if :new.saldo >v_saldoMax then
    dbms_output.put_line('saldo nuevo > saldo actual');
    RAISE_APPLICATION_ERROR(-20004,'ERROR: SALDO EXCESIVO');
    end if;
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


