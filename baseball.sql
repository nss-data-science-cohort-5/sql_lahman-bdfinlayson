-- ## Lahman Baseball Database Exercise
-- - this data has been made available [online](http://www.seanlahman.com/baseball-archive/statistics/) by Sean Lahman
-- - you can find a data dictionary [here](http://www.seanlahman.com/files/database/readme2016.txt)
--
-- 1. Find all players in the database who played at Vanderbilt University.
-- Create a list showing each player's first and last names as well as the total salary they earned in the major leagues.
-- Sort this list in descending order by the total salary earned. Which Vanderbilt player earned the most money in the majors?
--

with vandy_players as (
  select playerid from collegeplaying
    inner join schools s on collegeplaying.schoolid = s.schoolid
    where schoolname = 'Vanderbilt University'
)
select distinct p.playerid, namefirst, namelast, sum(salary) over(partition by p.playerid) total_salary
from people p
inner join salaries s2 on p.playerid = s2.playerid
where p.playerid in (select * from vandy_players)
order by total_salary desc;

select distinct namefirst, namelast, coalesce(sum(salary), 0) s, schoolname
from people
left join collegeplaying
using(playerid)
left join schools
using (schoolid)
left join salaries
using(playerid)
where schoolname = 'Vanderbilt University'
group by namefirst, namelast, schoolname
order by s desc

-- 2. Using the fielding table, group players into three groups based on their position: label players with position OF as "Outfield", those with position "SS", "1B", "2B", and "3B" as "Infield", and those with position "P" or "C" as "Battery". Determine the number of putouts made by each of these three groups in 2016.
--

with outfield as (
    select sum(po) as number_of_putouts, yearid as year, pos
    from fielding
    where pos = 'OF'
      and yearid = 2016
    group by pos, yearid
),
     infield as (
         select sum(po) as number_of_putouts, yearid as year, pos
         from fielding
         where pos in ('SS', '1B', '2B', '3B')
           and yearid = 2016
         group by pos, yearid
     ),
     battery as (
         select sum(po) as number_of_putouts, yearid as year, pos
         from fielding
         where pos in ('P', 'C')
           and yearid = 2016
         group by pos, yearid
     )
select sum(distinct outfield.number_of_putouts) outfield_pos,
       sum(distinct infield.number_of_putouts)           infield_pos,
       sum(distinct battery.number_of_putouts)           battery_pos
from outfield,
     infield,
     battery;

-- 3. Find the average number of strikeouts per game by decade since 1920. Round the numbers you report to 2 decimal places. Do the same for home runs per game. Do you see any trends? (Hint: For this question, you might find it helpful to look at the **generate_series** function (https://www.postgresql.org/docs/9.1/functions-srf.html). If you want to see an example of this in action, check out this DataCamp video: https://campus.datacamp.com/courses/exploratory-data-analysis-in-sql/summarizing-and-aggregating-numeric-data?ex=6)
--

select round(avg(so / g), 2)                                                avg_so_per_g,
       extract(decade from concat(yearid, '-01-01 00:00:00')::timestamp) * 10 as decade
from teams
where yearid >= 1920
group by decade
order by decade;

-- a cleaner way to get a decade from a year
select trunc(1988, -1);

-- 4. Find the player who had the most success stealing bases in 2016, where __success__ is measured as the percentage of stolen base attempts which are successful.
-- (A stolen base attempt results either in a stolen base or being caught stealing.)
-- Consider only players who attempted _at least_ 20 stolen bases.
-- Report the players' names, number of stolen bases, number of attempts, and stolen base percentage.
--

with steals as (
    select sum(sb) as successes,
           (sum(sb) + sum(cs)) as attempts,
           round((sum(sb) / (sum(sb) + sum(cs))::numeric), 3) * 100 as percentage,
           playerid
    from batting
    where sb > 0
    and cs > 0
    and yearid = 2016
    group by playerid
),
 stealing_players as (
     select concat(namefirst, ' ', namelast) as full_name, playerid
     from people
     inner join steals
     using (playerid)
 )
select *
from steals
inner join stealing_players using (playerid)
where attempts > 20
order by percentage desc

-- 5. From 1970 to 2016, what is the largest number of wins for a team that did not win the world series?
-- What is the smallest number of wins for a team that did win the world series?
-- Doing this will probably result in an unusually small number of wins for a world series champion; determine why this is the case.
-- Then redo your query, excluding the problem year.
-- How often from 1970 to 2016 was it the case that a team with the most wins also won the world series?
-- What percentage of the time?
--
with largest_non_winner as (
    select w, teamid
    from teams
    where wswin = 'N'
    and yearid between 1970 and 2016
    order by w desc
    limit 1
),
    smallest_winner as (
        select w, teamid
        from teams
        where wswin = 'Y'
        and yearid between 1970 and 2016
        order by w
        limit 1
)
select * from largest_non_winner
union
select * from smallest_winner
order by w desc;

select w, wswin, yearid
from teams
where yearid between 1970 and 2016
group by yearid
order by yearid


-- CORRECT ANSWER:

WITH max_wins AS (
	SELECT
		yearid,
		MAX(w) AS max_wins
	FROM teams
	WHERE yearid >= 1970
	GROUP BY yearid
	ORDER BY yearid
),
team_with_most_wins AS (
	SELECT m.yearid, max_wins, name, wswin
	FROM max_wins m
	INNER JOIN teams t
	ON max_wins = w AND m.yearid = t.yearid
)
SELECT
ROUND(
(SELECT COUNT(*)
FROM team_with_most_wins
WHERE wswin = 'Y') * 100.0 / (SELECT COUNT(*) FROM team_with_most_wins), 2) AS ws_win_pct;


-- 6. Which managers have won the TSN Manager of the Year award in both the National League (NL) and the American League (AL)? Give their full name and the teams that they were managing when they won the award.
--

select playerid, case when dense_rank() over(partition by playerid order by lgid) + dense_rank() over(partition by playerid order by lgid desc) - 1 = 2 then true else false end as won_in_both_leagues  from awardsmanagers where awardid = 'TSN Manager of the Year' and playerid = 'larusto01'

select playerid, lgid, dense_rank() over(partition by playerid order by lgid) + dense_rank() over(partition by playerid order by lgid desc) - 1 as won_in_both_leagues  from awardsmanagers where awardid = 'TSN Manager of the Year' and playerid = 'larusto01'

select playerid, awardid, lgid from awardsmanagers where playerid = 'larusto01'

with winners as (
    select playerid,
           yearid,
           lgid,
           -- hack for counting distinct values in a window function
           -- https://www.sqlservercentral.com/forums/topic/how-to-distinct-count-with-windows-functions-i-e-over-and-partition-by
           -- the first dense_rank assigns a 1 to the first unique lgids then a 2 to the next unique lgid
           -- the second dense_rank reverses the order, assigning a 2 to the first unique lgid then a 2 to the next unique lgids
           -- subtracting 1 then makes all values equal across rows (in this case 2 since we're only dealing with two leagues)
           case when dense_rank() over(partition by playerid order by lgid) + dense_rank() over(partition by playerid order by lgid desc) - 1 = 2
               then true
               else false
               end as won_in_both_leagues
    from awardsmanagers
    where awardid = 'TSN Manager of the Year'
    and lgid in ('NL', 'AL')
),
 managed_teams as (
    select distinct m.playerid,
                    t2.franchname,
                    m.teamid,
                    m.yearid,
                    t.lgid,
                    tsn.won_in_both_leagues
    from managers m
    inner join winners tsn
    on tsn.playerid = m.playerid
    and tsn.yearid = m.yearid
    inner join teams t
    on t.teamid = m.teamid
    inner join teamsfranchises t2
    on t.franchid = t2.franchid
 )
select mt.playerid,
       concat(p.namefirst, ' ', p.namelast) as full_name,
       mt.franchname team_name,
       mt.yearid as year,
       case when mt.lgid = 'AL' then 'American' else 'National' end as league
from managed_teams as mt
inner join people as p
on p.playerid = mt.playerid
where mt.won_in_both_leagues = true
order by playerid desc;


-- Michael's solution:

WITH winning_managers AS (
	SELECT playerid
	FROM awardsmanagers
	WHERE awardid = 'TSN Manager of the Year'
	AND lgid IN ('AL', 'NL')
	GROUP BY playerid
	HAVING COUNT(DISTINCT lgid) = 2)
SELECT
	namefirst || ' ' || namelast AS manager_name,
	yearid,
	name
FROM awardsmanagers
INNER JOIN people
USING(playerid)
INNER JOIN managers
USING (playerid, yearid)
INNER JOIN teams
USING (teamid, yearid)
WHERE awardid = 'TSN Manager of the Year'
AND playerid IN (SELECT * FROM winning_managers)
ORDER BY manager_name, yearid;

-- 7. Which pitcher was the least efficient in 2016 in terms of salary / strikeouts?
-- Only consider pitchers who started at least 10 games (across all teams).
-- Note that pitchers often play for more than one team in a season, so be sure that you are counting all stats for each player.
--
with pitcher_efficiency_2016 as (
    select (salary / so)::numeric::money as price_per_so,
           p.playerid
    from pitching as p
    inner join salaries as s
    on s.playerid = p.playerid
    and s.yearid = p.yearid
    and s.teamid = p.teamid
    where gs >= 10
    and p.yearid = 2016
)
select price_per_so, concat(p.namefirst, ' ', p.namelast) from pitcher_efficiency_2016
inner join people p
using (playerid)
order by price_per_so desc
limit 1


--- Michael's solution:

WITH full_pitching AS (
	SELECT
		playerid,
		SUM(so) AS so,
		SUM(g) AS g,
		SUM(gs) AS gs
	FROM pitching
	WHERE yearid = 2016
	GROUP BY playerid
),
full_salary AS (
	SELECT playerid, SUM(salary) AS salary
	FROM salaries
	WHERE yearid = 2016
	GROUP BY playerid
)
SELECT
	namefirst || ' ' || namelast AS fullname,
	salary / so AS dollars_per_so
FROM full_pitching
INNER JOIN full_salary
USING(playerid)
INNER JOIN people
USING(playerid)
WHERE g >= 10
ORDER BY dollars_per_so DESC;

-- 8. Find all players who have had at least 3000 career hits. Report those players' names, total number of hits, and the year they were inducted into the hall of fame (If they were not inducted into the hall of fame, put a null in that column.) Note that a player being inducted into the hall of fame is indicated by a 'Y' in the **inducted** column of the halloffame table.
--
-- 9. Find all players who had at least 1,000 hits for two different teams. Report those players' full names.
--
-- 10. Find all players who hit their career highest number of home runs in 2016. Consider only players who have played in the league for at least 10 years, and who hit at least one home run in 2016. Report the players' first and last names and the number of home runs they hit in 2016.
--
-- After finishing the above questions, here are some open-ended questions to consider.
--
-- **Open-ended questions**
--
-- 11. Is there any correlation between number of wins and team salary? Use data from 2000 and later to answer this question. As you do this analysis, keep in mind that salaries across the whole league tend to increase together, so you may want to look on a year-by-year basis.
--
-- 12. In this question, you will explore the connection between number of wins and attendance.
--
--     a. Does there appear to be any correlation between attendance at home games and number of wins?
--     b. Do teams that win the world series see a boost in attendance the following year? What about teams that made the playoffs? Making the playoffs means either being a division winner or a wild card winner.
--
--
-- 13. It is thought that since left-handed pitchers are more rare, causing batters to face them less often, that they are more effective. Investigate this claim and present evidence to either support or dispute this claim. First, determine just how rare left-handed pitchers are compared with right-handed pitchers. Are left-handed pitchers more likely to win the Cy Young Award? Are they more likely to make it into the hall of fame?