-- data for testing


-- CREATE DATABASE taxi_traker;

DROP TABLE IF EXISTS taxi_service;

DROP TABLE IF EXISTS vehicle_driver;

DROP TABLE IF EXISTS vehicle_position_history;

DROP TABLE IF EXISTS vehicle;

DROP TABLE IF EXISTS driver;

DROP TABLE IF EXISTS customer;

CREATE TABLE vehicle(
	id 			VARCHAR(8)  NOT NULL,
	make		VARCHAR(50) NOT NULL,
	model		VARCHAR(50) NOT NULL,
	"year"		INT2		NOT NULL,
	latitude	FLOAT		NOT NULL DEFAULT 0,
	longitude	FLOAT		NOT NULL DEFAULT 0,
	CONSTRAINT pk_vehicle2 PRIMARY KEY (id)
);

-- Insert default vehicles
INSERT INTO vehicle
	(id, make, 			model, "year")
VALUES
	('B-83-570', 'Volkswagen', 'Golf',  '2012' ),
	('X-03-024', 'Volkswagen', 'Jetta', '2016' ),
	('B-52-069', 'Volkswagen', 'Polo',  '2014' );

CREATE TABLE driver(
	id 			VARCHAR(36) NOT NULL,
	first_name 	VARCHAR(50) NOT NULL,
	last_name 	VARCHAR(50)	NOT NULL,
	email 		VARCHAR(320) NOT NULL,
	password 	TEXT		NOT NULL,
	CONSTRAINT pk_driver PRIMARY KEY(id)
);

CREATE TABLE vehicle_driver_status(
	id 			INT2 NOT NULL,
	description TEXT NOT NULL,
	CONSTRAINT pk_vehicle_driver_status PRIMARY KEY(id)
);

INSERT INTO vehicle_driver_status
	(id, description)
VALUES
	(1, 'Free'),
	(2, 'Busy');

CREATE TABLE vehicle_driver(
	vehicle_id 	VARCHAR(8) 	NOT NULL,
	driver_id	VARCHAR(36) NOT NULL,
	status		INT2		NOT NULL DEFAULT 1,
	CONSTRAINT pk_vehicle_driver PRIMARY KEY(vehicle_id, driver_id),
	CONSTRAINT fk_vehicle_vehicledriver_id FOREIGN KEY(vehicle_id)
		REFERENCES vehicle(id)
		ON DELETE CASCADE
		ON UPDATE CASCADE,
	CONSTRAINT fk_driver_vehicledriver_id FOREIGN KEY(driver_id)
		REFERENCES driver(id)
		ON DELETE CASCADE
		ON UPDATE CASCADE
	CONSTRAINT fk_vehicledriverstatus_vehicledriver_id FOREIGN KEY(status)
		REFERENCES vehicle_driver_status(id)
		ON DELETE CASCADE
		ON UPDATE CASCADE;
);

CREATE TABLE customer (
	id 			VARCHAR(36) NOT NULL,
	first_name 	VARCHAR(50) NOT NULL,
	last_name 	VARCHAR(50) NOT NULL,
	email 		VARCHAR(320) NOT NULL,
	password 	TEXT		NOT NULL,
	CONSTRAINT pk_costumer PRIMARY KEY(id)
);

CREATE TABLE vehicle_position_history(
	id			SERIAL		NOT NULL,
	vehicle_id	VARCHAR(8)	NOT NULL,
	latitude	FLOAT		NOT NULL,
	longitude	FLOAT		NOT NULL,
	"date" 		TIMESTAMPTZ	NOT NULL DEFAULT NOW(),
	CONSTRAINT pk_historical PRIMARY KEY(id),
	CONSTRAINT fk_vehicle_vehiclepositionhistory_id FOREIGN KEY(vehicle_id)
		REFERENCES vehicle(id)
		ON UPDATE CASCADE
		ON DELETE CASCADE
);

CREATE TABLE taxi_service(
	customer_id VARCHAR(36) NOT NULL,
	vehicle_id 	VARCHAR(8)  NOT NULL,
	driver_id	VARCHAR(36)	NOT NULL,
	user_latitude  FLOAT 	NOT NULL,
	user_longitude FLOAT 	NOT NULL,
	CONSTRAINT pk_taxi_service PRIMARY KEY(customer_id, vehicle_id),
	CONSTRAINT fk_customer_taxiservice_id FOREIGN KEY(customer_id)
		REFERENCES customer(id)
		ON DELETE CASCADE
		ON UPDATE CASCADE,
	CONSTRAINT fk_vehicledriver_taxiservice_id FOREIGN KEY(vehicle_id, driver_id)
		REFERENCES vehicle_driver(vehicle_id, driver_id)
		ON DELETE CASCADE
		ON UPDATE CASCADE
);

-- =========================================================================================
-- =========================================================================================
--
-- Functions:

/* -----------------------------------------------------------------------------------------
 * *****************************************************************************************
 * Result Codes:
 * Succes codes - httpStatusOk: 200
 * 0 = OK
 
 * User Errors - httpStatusOk: 200
 * -1 = EUS001 - Email already exists 
*/
DROP FUNCTION IF EXISTS customer_insert(VARCHAR, VARCHAR, VARCHAR, VARCHAR, TEXT);

CREATE OR REPLACE FUNCTION customer_insert(
        p_id 			VARCHAR(36),
        p_first_name 	VARCHAR(50),
        p_last_name 	VARCHAR(50),
        p_email 		VARCHAR(320),
        p_password		TEXT
)
RETURNS INT AS
$$
DECLARE
    counter INT2;
BEGIN    
    -- If the email is not null, validate that not exist
    IF p_email IS NOT NULL THEN
        SELECT COUNT(*) INTO counter FROM customer WHERE email = p_email;
        IF counter <> 0 THEN
            Return -1;
        END IF;
    END IF;

    INSERT INTO customer
        ( id,  first_name,   last_name,   email,   password)
    VALUES
        (p_id, p_first_name, p_last_name, p_email, p_password); 
    RETURN 0;   
END    
$$ LANGUAGE plpgsql;

/* -----------------------------------------------------------------------------------------
 * *****************************************************************************************
 * Result Codes:
 * Succes codes - httpStatusOk: 200
 * 0 = OK
 
 * User Errors - httpStatusOk: 200
 * -1 = EUS001 - Email already exists 
*/
DROP FUNCTION IF EXISTS driver_insert(VARCHAR, VARCHAR, VARCHAR, VARCHAR, TEXT);

CREATE OR REPLACE FUNCTION driver_insert(
        p_id 			VARCHAR(36),
        p_first_name 	VARCHAR(50),
        p_last_name 	VARCHAR(50),
        p_email 		VARCHAR(320),
        p_password		TEXT
)
RETURNS INT AS
$$
DECLARE
    counter INT2;
BEGIN    
    -- If the email is not null, validate that not exist
    IF p_email IS NOT NULL THEN
        SELECT COUNT(*) INTO counter FROM driver WHERE email = p_email;
        IF counter <> 0 THEN
            Return -1;
        END IF;
    END IF;

    INSERT INTO driver
        ( id,  first_name,   last_name,   email,   password)
    VALUES
        (p_id, p_first_name, p_last_name, p_email, p_password); 
    RETURN 0;   
END    
$$ LANGUAGE plpgsql;


/* -----------------------------------------------------------------------------------------
 * *****************************************************************************************
	New function
 	ResultCodes:
 	0 = El usuario no tiene un servicio actualment, se ejecuto la operacion de relacionar un servicio
 	1 = El usuario ya cuenta con un servicio previamente.
*/
DROP FUNCTION IF EXISTS taxi_service_insert(VARCHAR, FLOAT, FLOAT);

CREATE OR REPLACE FUNCTION taxi_service_insert(
        p_customer_id	 VARCHAR(36),
        p_user_latitude  FLOAT,
        p_user_longitude FLOAT
)
RETURNS TABLE(
	res_result_code	  INT2,
	res_vehicle_id    VARCHAR,
	res_customer_name VARCHAR
) AS
$$
DECLARE
    var_vehicle_id VARCHAR;
	var_driver_id VARCHAR;
BEGIN    
    SELECT vehicle_id INTO var_vehicle_id 
    FROM taxi_service
    WHERE customer_id = p_customer_id;

	IF var_vehicle_id IS NOT NULL THEN
		RETURN QUERY(
			SELECT 1::INT2, var_vehicle_id, ''::VARCHAR
		);
		RETURN;
	END IF;
	
	SELECT vehicle_id, driver_id INTO var_vehicle_id, var_driver_id 
	FROM vehicle_driver
	WHERE status = 1
	LIMIT 1;

	IF var_vehicle_id IS NULL THEN
		RETURN QUERY(
			SELECT 0::INT2, ''::VARCHAR, ''::VARCHAR
		);
		RETURN ;
	END IF;

	INSERT INTO taxi_service 
		(customer_id,   vehicle_id,     driver_id,     user_latitude,   user_longitude)
	VALUES
		(p_customer_id, var_vehicle_id, var_driver_id, p_user_latitude, p_user_longitude);

	UPDATE vehicle_driver
	SET	status = 2
	WHERE vehicle_id = var_vehicle_id
		AND driver_id = var_driver_id;
	
	RETURN QUERY(
		SELECT 0::INT2, var_vehicle_id, first_name
		FROM customer
		WHERE id = p_customer_id
	);
	RETURN;
END    
$$ LANGUAGE plpgsql;

SELECT * FROM taxi_service_insert('d1030c00-116c-4a6e-b717-eb0b8147ed3d', 1.224523::FLOAT, 2.123123::FLOAT);


/* -----------------------------------------------------------------------------------------
 * *****************************************************************************************
	new function
*/
DROP FUNCTION IF EXISTS vehicle_driver_insert(VARCHAR, VARCHAR);

CREATE OR REPLACE FUNCTION vehicle_driver_insert(
        p_vehicle_id VARCHAR(8),
        p_driver_id	 VARCHAR(36)
)
RETURNS INT AS
$$
DECLARE
    counter INT2;
BEGIN    
    SELECT COUNT(*) INTO counter
    FROM vehicle_driver
    WHERE vehicle_id = p_vehicle_id
    	AND driver_id = p_driver_id;
	
	IF counter = 0 THEN
		INSERT INTO vehicle_driver
			(vehicle_id,   driver_id	)
		VALUES
			(p_vehicle_id, p_driver_id	);
	END IF;
	RETURN 0;
END    
$$ LANGUAGE plpgsql;




