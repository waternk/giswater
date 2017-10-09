﻿
CREATE OR REPLACE FUNCTION ws30.gw_fct_mincut_flowtrace_engine(
    node_id_arg character varying,
    result_id_arg integer)
  RETURNS void AS
$BODY$
DECLARE
    exists_id      character varying;
    rec_table      record;
    controlValue   integer;
    node_aux       public.geometry;
    arc_aux        public.geometry;
    stack          varchar[];    

BEGIN

    -- Search path
    SET search_path = "ws30", public;

    --Push first element into the array
    stack := array_append(stack, node_id_arg);

    --Main loop
    WHILE (array_length(stack, 1) > 0) LOOP

        --Get next element
        node_id_arg = stack[array_length(stack, 1)];
        
        -- Get v_edit_node public.geometry
        SELECT the_geom INTO node_aux FROM v_edit_node JOIN value_state_type ON state_type=value_state_type.id WHERE node_id = node_id_arg AND (is_operative IS TRUE);

        -- Check  v_edit_node being a valve
        SELECT node_id INTO exists_id FROM anl_mincut_result_valve WHERE node_id = node_id_arg AND (proposed IS TRUE) AND (result_id=result_id_arg);
        IF FOUND THEN 

	    RAISE NOTICE 'node valvula %', node_id_arg;
            --Remove element form array
            stack := stack[1:(array_length(stack,1) - 1)];
            
        ELSE

            -- Check if the v_anl_node is already computed
            RAISE NOTICE 'node normal %', node_id_arg;
            SELECT node_id INTO exists_id FROM anl_mincut_result_node WHERE node_id = node_id_arg AND result_id=result_id_arg;
            IF NOT FOUND THEN

                -- Update value
                RAISE NOTICE 'node insertat a taula result %', node_id_arg;
                INSERT INTO anl_mincut_result_node (node_id, the_geom, result_id) VALUES(node_id_arg, node_aux, result_id_arg);
        
                -- Loop for all the upstream nodes
                FOR rec_table IN SELECT arc_id, node_1 FROM v_edit_arc JOIN value_state_type ON state_type=value_state_type.id 
                WHERE node_2 = node_id_arg AND (is_operative IS TRUE)
                LOOP

                    -- Insert into tables
                    SELECT arc_id INTO exists_id FROM anl_mincut_result_arc WHERE arc_id = rec_table.arc_id;
                    IF NOT FOUND THEN

                     -- Insert into tables
                        RAISE NOTICE 'arc a/amunt insertat a taula result %', rec_table.arc_id;
                        SELECT the_geom INTO arc_aux FROM v_edit_arc JOIN value_state_type ON state_type=value_state_type.id 
                        WHERE arc_id = rec_table.arc_id AND (is_operative IS TRUE);
                        INSERT INTO anl_mincut_result_arc (arc_id, the_geom, result_id) VALUES (rec_table.arc_id, arc_aux, result_id_arg);
                    END IF;

                    --Push element into the array
                    stack := array_append(stack, rec_table.node_1);
                    
                END LOOP;

                -- Loop for all the downstream nodes
                FOR rec_table IN SELECT arc_id, node_2 FROM v_edit_arc WHERE node_1 = node_id_arg
                LOOP

                    -- Insert into tables
                    RAISE NOTICE 'arc a/amunt insertat a taula result %', rec_table.arc_id;
                    SELECT arc_id INTO exists_id FROM anl_mincut_result_arc WHERE arc_id = rec_table.arc_id;
                    IF NOT FOUND THEN

		     -- Insert into tables
                        SELECT the_geom INTO arc_aux FROM v_edit_arc JOIN value_state_type ON state_type=value_state_type.id 
                        WHERE arc_id = rec_table.arc_id AND (is_operative IS TRUE);
                        INSERT INTO anl_mincut_result_arc (arc_id, the_geom, result_id) VALUES (rec_table.arc_id, arc_aux, result_id_arg);
                    END IF;

                    --Push element into the array
                    stack := array_append(stack, rec_table.node_2);

                END LOOP;

            ELSE

                --Remove element form array
                stack := stack[1:(array_length(stack,1) - 1)];

            END IF;
        END IF;

    END LOOP;

    RETURN;
        
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION ws30.gw_fct_mincut_flowtrace_engine(character varying, integer)
  OWNER TO postgres;
