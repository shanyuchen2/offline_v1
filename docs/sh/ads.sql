DROP TABLE IF EXISTS ads_traffic_stats_by_channel;
CREATE EXTERNAL TABLE ads_traffic_stats_by_channel
(
    `dt`               STRING COMMENT '统计日期',
    `recent_days`      BIGINT COMMENT '最近天数,1:最近1天,7:最近7天,30:最近30天',
    `channel`          STRING COMMENT '渠道',
    `uv_count`         BIGINT COMMENT '访客人数',
    `avg_duration_sec` BIGINT COMMENT '会话平均停留时长，单位为秒',
    `avg_page_count`   BIGINT COMMENT '会话平均浏览页面数',
    `sv_count`         BIGINT COMMENT '会话数',
    `bounce_rate`      DECIMAL(16, 2) COMMENT '跳出率'
) COMMENT '各渠道流量统计'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_traffic_stats_by_channel/';


insert overwrite table ads_traffic_stats_by_channel
select * from ads_traffic_stats_by_channel
union
select
    '20250916' ,dt,
    recent_days,
    channel,
    cast(count(distinct(mid_id)) as bigint) uv_count,
    cast(avg(during_time_1d)/1000 as bigint) avg_duration_sec,
    cast(avg(page_count_1d) as bigint) avg_page_count,
    cast(count(*) as bigint) sv_count,
    cast(sum(if(page_count_1d=1,1,0))/count(*) as decimal(16,2)) bounce_rate
from dws_traffic_session_page_view_1d lateral view explode(array(1,7,30)) tmp as recent_days
group by recent_days,channel;

select *
from ads_traffic_stats_by_channel;

DROP TABLE IF EXISTS ads_page_path;
CREATE EXTERNAL TABLE ads_page_path
(
    `dt`          STRING COMMENT '统计日期',
    `source`      STRING COMMENT '跳转起始页面ID',
    `target`      STRING COMMENT '跳转终到页面ID',
    `path_count`  BIGINT COMMENT '跳转次数'
) COMMENT '页面浏览路径分析'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_page_path/';

insert overwrite table ads_page_path
select * from ads_page_path
union
select
    '20250916' dt,
    source,
    nvl(target,'null'),
    count(*) path_count
from
    (
        select
            concat('step-',rn,':',page_id) source,
            concat('step-',rn+1,':',next_page_id) target
        from
            (
                select
                    page_id,
                    lead(page_id,1,null) over(partition by session_id order by view_time) next_page_id,
                    row_number() over (partition by session_id order by view_time) rn
                from dwd_traffic_page_view_inc
                where dt='20250916'
            )t1
    )t2
group by source,target;

