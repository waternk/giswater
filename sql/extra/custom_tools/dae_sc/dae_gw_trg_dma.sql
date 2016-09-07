/*
This file is part of Giswater 2.0
The program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
This version of Giswater is provided by Giswater Association
*/


CREATE OR REPLACE FUNCTION "SCHEMA_NAME".dae_gw_trg_dma() RETURNS trigger LANGUAGE plpgsql AS $BODY$
DECLARE 
    v_sql varchar;
    geom_column varchar;
    num_dmas integer;
    r record;

BEGIN

    EXECUTE 'SET search_path TO '||quote_literal(TG_TABLE_SCHEMA)||', public';

    -- Dynamic SQL
    v_sql:= 'SELECT
                 tc.table_name,
                 kcu.column_name
             FROM 
                 information_schema.table_constraints AS tc JOIN
                 information_schema.key_column_usage AS kcu ON tc.constraint_name = kcu.constraint_name JOIN
                 information_schema.constraint_column_usage AS ccu ON ccu.constraint_name = tc.constraint_name
             WHERE
                 tc.constraint_type = ' || quote_literal('FOREIGN KEY') || ' AND
                 tc.constraint_schema=' || quote_literal(TG_TABLE_SCHEMA) || ' AND
                 tc.table_schema=' || quote_literal(TG_TABLE_SCHEMA) || ' AND
                 kcu.constraint_schema=' || quote_literal(TG_TABLE_SCHEMA) || ' AND                 
                 ccu.table_schema=' || quote_literal(TG_TABLE_SCHEMA) || ' AND
                 ccu.table_name=' || quote_literal('dma') || ' AND
                 ccu.column_name=' || quote_literal('dma_id');

    -- Loop for all the tables with a foreign key in dma_id
    FOR r IN EXECUTE v_sql
    LOOP

        --Find the geometry column name
        v_sql:= 'SELECT f_geometry_column FROM geometry_columns WHERE f_table_schema=' || quote_literal(TG_TABLE_SCHEMA) || ' AND f_table_name=' || quote_literal(r.table_name); 
        EXECUTE v_sql INTO geom_column;

        -- In case of no geom
        IF geom_column IS NOT NULL THEN

            -- Check orphan
            v_sql:= 'SELECT COUNT(*) FROM ' || quote_ident(r.table_name) || ' WHERE (SELECT COUNT(*) FROM dma WHERE ST_Intersects(' || quote_ident(r.table_name) || '.' || quote_ident(geom_column) || ', dma.the_geom) LIMIT 1)=0';
            EXECUTE v_sql INTO num_dmas;

            IF num_dmas > 0 THEN
                RAISE NOTICE 'num_dmas= %', num_dmas;        
                -- RAISE EXCEPTION 'There are features in table % outside of the dma polygons', r.table_name;
            END IF;

            -- Update dma id       
            v_sql:= 'UPDATE ' || quote_ident(r.table_name) || ' SET ' || quote_ident(r.column_name) || ' = (SELECT dma_id FROM dma WHERE ST_Intersects(' || quote_ident(r.table_name) || '.' || quote_ident(geom_column) || ', dma.the_geom) LIMIT 1)';
            EXECUTE v_sql;

        END IF;
    
    END LOOP;

    RETURN NEW;

END;
$BODY$;


CREATE TRIGGER dae_gw_trg_dma AFTER INSERT ON "SCHEMA_NAME"."dma"
FOR EACH ROW EXECUTE PROCEDURE "SCHEMA_NAME"."dae_gw_trg_dma"();



CREATE TRIGGER dae_gw_trg_dma_update AFTER UPDATE OF the_geom ON "SCHEMA_NAME"."dma" 
FOR EACH ROW EXECUTE PROCEDURE "SCHEMA_NAME"."dae_gw_trg_dma"();
