/*----SQL AVANZADO----
	
    MÉTODOS
		2 TIPOS EN PROGRAMACIÓN:
			void --> Sin retorno de resultados o salidas __ejm _ public class void (){}
            salida --> Con retorno de salida en base a 1 tipo de dato conocido o definido__ejm _ public class string(){}, public class int(){}
		2 TIPOS EN SQL AVANZADO:
			Procesamientos Almacenados --> Sin retorno de resultados o salidas
            funciones --> Con retorno de salida en base a 1 tipo de dato conocido o definido
				-Tipos de funciones
					°Funciones Escalares
                    °Funciones con valores de tabla
						-Insertado --> hay MySql Server
                        -Multiples Instrucciones --> hay MySql Server
*/

-- CALCULAR EL IVA (Impuestos)
DELIMITER $$
CREATE FUNCTION ufcIVA(_monto DECIMAL(7,2))
RETURNS DECIMAL(7,2)DETERMINISTIC
BEGIN
	DECLARE _res DECIMAL (7,2);
    SET _res = 0.13*_monto;
    RETURN _res;
END
$$
/*PROBAMOS  LA FUNCION*/
SELECT id AS ID,descripcion AS Descripcion, precioBase AS 'Precio Base', ufcIVA(precioBase) AS IVA
FROM producto

-- DADO EL ID DE UN CLIENTE SE RETORNE EL TOTAL (BS.) DE COMPRAS REALIZADAS POR DICHO CLIENTE, QUE MPS RETORNE SU NIR Y RAZON SOCIAL

DROP FUNCTION ufcClienteTotal;

DELIMITER $$
CREATE FUNCTION ufcClienteTotal(_id SMALLINT)
RETURNS VARCHAR(80)DETERMINISTIC
BEGIN
	DECLARE _res VARCHAR(80);
    DECLARE _cliente VARCHAR(80);
    DECLARE _total DECIMAL (18,2);
    /* UNA FORMA DE ASIGNAR VALOR A UNA VARIABLE
    SET _total=(SELECT IFNULL(SUM(total),0)
			  FROM venta
			  WHERE idCliente=_id);
	RETURN _res; */
    -- solo en MySql se puede hacer esto
    IF EXISTS (SELECT id FROM cliente WHERE id=_id) THEN
		SELECT IFNULL(SUM(total),0) INTO _total
		FROM venta
		WHERE idCliente=_id;
    
		SELECT CONCAT(ciNit, ' -  ',razonSocial) INTO _cliente
		FROM cliente
		WHERE id=_id;
        
        SET _res = CONCAT(_cliente,' - ',_total,' Bs.'); 
        
	ELSE
		SET _res='Id del Cliente No Existe en la Base de Datos';
    END IF;

    RETURN _res;
END
$$

SELECT ufcClienteTotal(200);

SELECT ufcClienteTotal(id) AS 'Datos Cliente'
FROM cliente;

-- DADO UN ID DE UN CLIENTE, OBTENER SU TOTAL COMPRADO, PARA LUEGO GENERAR EL SIGUENTE MENSAJE..., 
-- EL RESULTADO DE LA FUNCION ES EL TOTAL RECAUDADO INCLUYENDO EL MENSAJE EN CASO DE QUE EL CLIENTE NO EXITA, RETORNAR EL MENSAJE cliente inexistente
DELIMITER $$
CREATE FUNCTION ufcClienteClasificacion (_id SMALLINT)
RETURNS VARCHAR(50)DETERMINISTIC
BEGIN
	DECLARE _res VARCHAR(50) DEFAULT 'Cliente Inexistente en la BDD.';
    DECLARE _x DECIMAL (18,2);
    DECLARE _mensaje VARCHAR(30);
    
    IF EXISTS(SELECT id FROM cliente WHERE id=_id) THEN
		SELECT IFNULL(SUM(total),0) INTO _x
		FROM venta
		WHERE idCliente=_id;
        
        CASE
			WHEN _x<200 THEN SET _mensaje='Cliente poco Regular';
            WHEN _x<1000 THEN SET _mensaje='Cliente Regular Inferior';
            WHEN _x<3000 THEN SET _mensaje='Cliente Regular';
            WHEN _x<5000 THEN SET _mensaje='Cliente Bueno';
            WHEN _x<10000 THEN SET _mensaje='Cliente Excelente';
            
            ELSE SET _mensaje='Cliente Fiel';
        END CASE;
        
        SET _res=CONCAT(_x,' Bs. - ',_mensaje); 
    END IF;
    
    RETURN _res;

END
$$

SELECT ufcClienteClasificacion(800) AS 'Info. Cliente';

SELECT ciNit AS NIT, razonSocial AS 'Razón Social', ufcClienteClasificacion(id) AS Clasificacion
FROM cliente;

----------- CICLOS WHILE -----------
DROP FUNCTION ufcEjemplo;
DELIMITER $$
CREATE FUNCTION ufcEjemplo(_inic INT, _fin INT)
RETURNS VARCHAR(1000)DETERMINISTIC
BEGIN
	DECLARE _res VARCHAR(1000) DEFAULT '';
    
    WHILE (_inic <= _fin) DO
		SET _res = CONCAT(_res,' ',_inic);
		SET _inic =_inic+1;
    END WHILE;
    
    RETURN _res;
END
$$

SELECT ufcEjemplo(5,25);

-- CREAR UNA FUNCION QUE RETORNE EN UNA SOLA CADENA TODOS LOS NIT DE LOS CLIENTES EXISTENTES EN LA BASE DE DATOS
DROP FUNCTION ufcClienteNit;
DELIMITER $$
CREATE FUNCTION ufcClienteNit(_finNit INT)
RETURNS VARCHAR(60000)DETERMINISTIC
BEGIN 
	DECLARE _res VARCHAR(60000) DEFAULT '';
    DECLARE _ini, _fin SMALLINT;

    SELECT MIN(id), MAX(id) INTO _ini, _fin
    FROM cliente;
    
    WHILE (_ini <= _fin AND _ini<=_finNit) DO
		IF EXISTS(SELECT id FROM cliente WHERE id=_ini) THEN
			SELECT CONCAT(_res, ' - ', ciNit) INTO _res
            FROM cliente
            WHERE id=_ini AND estado=1;
        END IF;
		SET _ini=_ini+1;
    END WHILE;
    
    RETURN _res;
END
$$

SELECT ufcClienteNit(5);

/*Crear una función que reciba el ID de un producto para luego desplegar la información en una sola cadena:
	-	Descripción
	-	Unidad de medida
	-	Saldo
	-	Precio
	-	Cantidad Total de Unidades vendidas (Solo de ventas validas)
	-	Total Bs. Acumulado en todas sus ventas (Solo ventas validas)(1=valida/2=invalida)
	-	Porcentaje de Incremento o Decremento del Saldo vs Cantidad Total de Unidades Vendidas bajo el siguiente criterio:
		o	Sea x: Saldo del Producto
		o	Sea y: Cantidad Total de Unidades vendidas
		o	Si x>y; calcular el porcentaje por el cual x supera a y y concatenar con el siguiente mensaje: “Existe un z Porcentaje en el Saldo que supera a las ventas”
		o	Donde Z es el porcentaje calculado:
		o	Si x<y; calcular el porcentaje por le cual x se diferencia de y y concatenar con el siguiente mensaje: “Existe un z Porcentaje en el Saldo en el saldo inferior a las ventas”
		o	Si x=y; el mensaje será “No existe diferencia entre Saldo y Ventas”.
-	En caso de NO existir el ID ingresado en la BDD, mostrar el mensaje: “Id inexistente en la BDD”.*/

DELIMITER $$
CREATE FUNCTION ufcEjercicio1(_id INT)
RETURNS VARCHAR(500)DETERMINISTIC
BEGIN
	DECLARE _res VARCHAR(500) DEFAULT 'ID inexistente en la Base de Datos. :( ';
	DECLARE _descripcion, _unidadMedida, _precioBase, _mensaje VARCHAR(80);
    DECLARE _porcentaje, _totalBsVendido DECIMAL(8,2);
    DECLARE _saldo, _cantidadVendido INT;
    
    IF EXISTS (SELECT * FROM producto WHERE id=_id) THEN
		SELECT P.descripcion, P.unidadMedida, P.saldo, P.precioBase, SUM(D.cantidad), SUM(D.cantidad*D.precioUnitario) INTO _descripcion, _unidadMedida, _saldo, _precioBase, _cantidadVendido, _totalBsVendido
        FROM producto P
        INNER JOIN detalle D ON P.id=D.idProducto
        INNER JOIN venta V ON D.idVenta=V.id
        WHERE D.idProducto=_id AND V.estado=1;
        
        IF (_saldo > _cantidadVendido) THEN
			SET _porcentaje = ((_saldo - _cantidadVendido) / _saldo) * 100;
            SET _mensaje= CONCAT('Existe un Incremento de ', _porcentaje ,'% en el Saldo que supera a las ventas.');
		ELSE
			IF (_saldo < _cantidadVendido) THEN
				SET _porcentaje = ((_cantidadVendido - _saldo) / _saldo) * 100;
				SET _mensaje= CONCAT('Existe un Decremento de ', _porcentaje ,'% en el Saldo en el saldo inferior a las ventas.');
            
            ELSE
				SET _mensaje= 'No existe diferencia entre saldo y vendas.';
			END IF;
		END IF;
        
        SET _res = CONCAT('Descipcion: ',_descripcion,' - Unidad de Medida: ',_unidadMedida,' - Saldo del Producto: ',_saldo,' - Precio Base ',_precioBase,' - Cantidad de Producto Vendido: ',_cantidadVendido,' - Total acumulados: ',_totalBsVendido,'Bs. - ',_mensaje);
        
	END IF;
    
    RETURN _res;
END
$$

SELECT ufcEjercicio1(13) AS 'Información del Producto';
























