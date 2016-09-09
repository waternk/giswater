/*
This file is part of Giswater 2.0
The program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
This version of Giswater is provided by Giswater Association
*/
SET search_path = "SCHEMA_NAME", public, pg_catalog;


DROP VIEW IF EXISTS v_rtc_hydrometer_x_connec;
CREATE OR REPLACE VIEW v_rtc_hydrometer_x_connec AS
SELECT 
connec_id,
count(hydrometer_id)::integer as n_hydrometer

FROM rtc_hydrometer_x_connec
group by connec_id;


DROP VIEW IF EXISTS v_edit_connec;
CREATE OR REPLACE VIEW v_edit_connec AS
SELECT connec.connec_id, 
connec.elevation, 
connec.depth, 
connec.connecat_id,
cat_connec.type AS "cat_connectype_id",
cat_connec.matcat_id AS "cat_matcat_id",
cat_connec.pnom AS "cat_pnom",
cat_connec.dnom AS "cat_dnom",
connec.sector_id, 
connec.code,
v_rtc_hydrometer_x_connec.n_hydrometer,
connec.demand,
connec."state", 
connec.annotation, 
connec.observ, 
connec."comment",
connec.dma_id,
dma.presszonecat_id,
connec.soilcat_id,
connec.category_type,
connec.fluid_type,
connec.location_type,
connec.workcat_id,
connec.buildercat_id,
connec.builtdate,
connec.ownercat_id,
connec.adress_01,
connec.adress_02,
connec.adress_03,
connec.streetaxis_id,
ext_streetaxis.name,
connec.postnumber,
connec.descript,
vnode.arc_id,
cat_connec.svg AS "cat_svg",
connec.rotation,
connec.link,
connec.verified,
connec.the_geom
FROM (connec
JOIN cat_connec ON (((connec.connecat_id)::text = (cat_connec.id)::text))
LEFT JOIN v_rtc_hydrometer_x_connec ON (((connec.connec_id)::text = (v_rtc_hydrometer_x_connec.connec_id)::text))
LEFT JOIN ext_streetaxis ON (((connec.streetaxis_id)::text = (ext_streetaxis.id)::text))
LEFT JOIN link ON connec.connec_id::text = link.connec_id::text
LEFT JOIN vnode ON vnode.vnode_id::text = link.vnode_id
LEFT JOIN dma ON (((connec.dma_id)::text = (dma.dma_id)::text)));

