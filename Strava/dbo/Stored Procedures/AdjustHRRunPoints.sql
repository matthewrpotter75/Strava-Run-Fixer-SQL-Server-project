CREATE PROCEDURE dbo.AdjustHRRunPoints
(
	@TableName VARCHAR(100),
	@StartDeleteMovingTime TIME,
	@EndDeleteMovingTime TIME,
	@StartDeleteTimeId INT,
	@EndDeleteTimeId INT,
	@StartDeleteTime DATETIME,
	@EndDeleteTime DATETIME,
	@HRTimeLimitAfterStop INT = 300,
	@Debug TINYINT = 0
)
AS
BEGIN

	SET NOCOUNT ON;

	BEGIN TRY

		DECLARE @ErrorMessage NVARCHAR(MAX),
				@ErrorSeverity INT,
				@ErrorState INT;

		DECLARE @StartHR INT,
				@EndHR INT,
				@TimeAddedAfterStopIds INT,
				--@NextIdOfSameHR INT,
				@EndFixHRId INT,
				@DiffTime INT,
				@SQL NVARCHAR(2000);

		SELECT @StartHR = LAG(HR,1) OVER (ORDER BY Id) 
		FROM #RunPointsTable 
		WHERE Id IN (@StartDeleteTimeId,@StartDeleteTimeId - 1);

		SELECT @EndFixHRId = MIN(Id) 
		FROM #RunPointsTable 
		WHERE MovingTime >= @EndDeleteMovingTime 
		AND MovingTime <= DATEADD(s,@HRTimeLimitAfterStop,@EndDeleteMovingTime)
		AND HR >= @StartHR;

		SELECT @EndHR = MAX(HR) 
		FROM #RunPointsTable 
		WHERE MovingTime >= @EndDeleteMovingTime 
		AND MovingTime <= DATEADD(s,@HRTimeLimitAfterStop,@EndDeleteMovingTime);
			
		IF @EndFixHRId IS NULL
		BEGIN

			--Set end time to look for max HR as x mins after end delete time
			SELECT @EndFixHRId = MIN(Id) 
			FROM #RunPointsTable 
			WHERE MovingTime >= @EndDeleteMovingTime 
			AND MovingTime <= DATEADD(s,@HRTimeLimitAfterStop,@EndDeleteMovingTime)
			AND HR = @EndHR;

		END

		IF @Debug = 1
		BEGIN

			SELECT @EndFixHRId AS EndFixHRId, @EndFixHRId AS EndFixHRId, @StartHR AS StartHR, @EndHR AS EndHR;

			SELECT @EndFixHRId AS EndFixHRId, @StartHR AS StartHR, @EndHR AS EndHR, DATEADD(s,@HRTimeLimitAfterStop,@EndDeleteMovingTime) AS UpperMovingTimeLimit;

		END

		IF @EndFixHRId IS NOT NULL
		BEGIN

			IF @Debug = 1
			BEGIN

				PRINT 'Adjusting HR';

				SELECT @StartHR AS StartHR, @EndHR AS EndHR, @EndDeleteTimeId AS EndDeleteTimeId, @EndFixHRId AS EndFixHRId;

			END
		
			--Adjust HR for all rows between end delete time and the end fix HR id
			--SET @SQL = '
			--UPDATE [Strava].[dbo].' + @TableName + '
			--SET HR = CASE WHEN DATEPART(second,MovingTime) % 2 = 1 THEN ' + CAST(@EndHR AS VARCHAR(3)) + ' ELSE ' + CAST((@EndHR + 1) AS VARCHAR(3)) + ' END, IsAdjustHR = 1 
			--WHERE Id >= ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + '
			--AND Id < ' + CAST(@EndFixHRId AS VARCHAR(10)) + ';';

			SET @SQL = '
			UPDATE [Strava].[dbo].' + @TableName + '
			SET HR = 
			CASE
				WHEN DATEPART(second,MovingTime) % 12 = 1 THEN ' + CAST(@StartHR AS VARCHAR(3)) + ' + ROUND((' + CAST(@EndHR AS VARCHAR(3))  + ' - ' + CAST(@StartHR AS VARCHAR(3)) + ') *  (CAST((Id - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ') AS DECIMAL(6,3))/(' + CAST(@EndFixHRId AS VARCHAR(10)) + ' - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ')),0.1) -1
				WHEN DATEPART(second,MovingTime) % 12 = 2 THEN ' + CAST(@StartHR AS VARCHAR(3)) + ' + ROUND((' + CAST(@EndHR AS VARCHAR(3))  + ' - ' + CAST(@StartHR AS VARCHAR(3)) + ') *  (CAST((Id - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ') AS DECIMAL(6,3))/(' + CAST(@EndFixHRId AS VARCHAR(10)) + ' - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ')),0.1) -2
				WHEN DATEPART(second,MovingTime) % 12 = 3 THEN ' + CAST(@StartHR AS VARCHAR(3)) + ' + ROUND((' + CAST(@EndHR AS VARCHAR(3))  + ' - ' + CAST(@StartHR AS VARCHAR(3)) + ') *  (CAST((Id - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ') AS DECIMAL(6,3))/(' + CAST(@EndFixHRId AS VARCHAR(10)) + ' - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ')),0.1) -3
				WHEN DATEPART(second,MovingTime) % 12 = 4 THEN ' + CAST(@StartHR AS VARCHAR(3)) + ' + ROUND((' + CAST(@EndHR AS VARCHAR(3))  + ' - ' + CAST(@StartHR AS VARCHAR(3)) + ') *  (CAST((Id - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ') AS DECIMAL(6,3))/(' + CAST(@EndFixHRId AS VARCHAR(10)) + ' - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ')),0.1) -2
				WHEN DATEPART(second,MovingTime) % 12 = 5 THEN ' + CAST(@StartHR AS VARCHAR(3)) + ' + ROUND((' + CAST(@EndHR AS VARCHAR(3))  + ' - ' + CAST(@StartHR AS VARCHAR(3)) + ') *  (CAST((Id - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ') AS DECIMAL(6,3))/(' + CAST(@EndFixHRId AS VARCHAR(10)) + ' - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ')),0.1) -1
				WHEN DATEPART(second,MovingTime) % 12 = 6 THEN ' + CAST(@StartHR AS VARCHAR(3)) + ' + ROUND((' + CAST(@EndHR AS VARCHAR(3))  + ' - ' + CAST(@StartHR AS VARCHAR(3)) + ') *  (CAST((Id - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ') AS DECIMAL(6,3))/(' + CAST(@EndFixHRId AS VARCHAR(10)) + ' - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ')),0.1)
				WHEN DATEPART(second,MovingTime) % 12 = 7 THEN ' + CAST(@StartHR AS VARCHAR(3)) + ' + ROUND((' + CAST(@EndHR AS VARCHAR(3))  + ' - ' + CAST(@StartHR AS VARCHAR(3)) + ') *  (CAST((Id - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ') AS DECIMAL(6,3))/(' + CAST(@EndFixHRId AS VARCHAR(10)) + ' - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ')),0.1) -1
				WHEN DATEPART(second,MovingTime) % 12 = 8 THEN ' + CAST(@StartHR AS VARCHAR(3)) + ' + ROUND((' + CAST(@EndHR AS VARCHAR(3))  + ' - ' + CAST(@StartHR AS VARCHAR(3)) + ') *  (CAST((Id - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ') AS DECIMAL(6,3))/(' + CAST(@EndFixHRId AS VARCHAR(10)) + ' - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ')),0.1) -2
				WHEN DATEPART(second,MovingTime) % 12 = 9 THEN ' + CAST(@StartHR AS VARCHAR(3)) + ' + ROUND((' + CAST(@EndHR AS VARCHAR(3))  + ' - ' + CAST(@StartHR AS VARCHAR(3)) + ') *  (CAST((Id - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ') AS DECIMAL(6,3))/(' + CAST(@EndFixHRId AS VARCHAR(10)) + ' - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ')),0.1) -3
				WHEN DATEPART(second,MovingTime) % 12 = 10 THEN ' + CAST(@StartHR AS VARCHAR(3)) + ' + ROUND((' + CAST(@EndHR AS VARCHAR(3))  + ' - ' + CAST(@StartHR AS VARCHAR(3)) + ') *  (CAST((Id - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ') AS DECIMAL(6,3))/(' + CAST(@EndFixHRId AS VARCHAR(10)) + ' - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ')),0.1) -2
				WHEN DATEPART(second,MovingTime) % 12 = 11 THEN ' + CAST(@StartHR AS VARCHAR(3)) + ' + ROUND((' + CAST(@EndHR AS VARCHAR(3))  + ' - ' + CAST(@StartHR AS VARCHAR(3)) + ') *  (CAST((Id - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ') AS DECIMAL(6,3))/(' + CAST(@EndFixHRId AS VARCHAR(10)) + ' - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ')),0.1) -1
				WHEN DATEPART(second,MovingTime) % 12 = 0 THEN ' + CAST(@StartHR AS VARCHAR(3)) + ' + ROUND((' + CAST(@EndHR AS VARCHAR(3))  + ' - ' + CAST(@StartHR AS VARCHAR(3)) + ') *  (CAST((Id - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ') AS DECIMAL(6,3))/(' + CAST(@EndFixHRId AS VARCHAR(10)) + ' - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ')),0.1)
				ELSE ' + CAST(@EndHR AS VARCHAR(3)) + ' 
			END, 
			IsAdjustHR = 1 
			WHERE Id >= ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + '
			AND Id < ' + CAST(@EndFixHRId AS VARCHAR(10)) + ';';

			EXEC sp_executesql @SQL;

			IF @Debug = 1
			BEGIN

				PRINT @SQL;

				SET @SQL = '
				SELECT *, 
				HR = 
				CASE
					WHEN DATEPART(second,MovingTime) % 12 = 1 THEN ' + CAST(@StartHR AS VARCHAR(3)) + ' + ROUND((' + CAST(@EndHR AS VARCHAR(3))  + ' - ' + CAST(@StartHR AS VARCHAR(3)) + ') *  (CAST((Id - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ') AS DECIMAL(6,3))/(' + CAST(@EndFixHRId AS VARCHAR(10)) + ' - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ')),0.1) -1
					WHEN DATEPART(second,MovingTime) % 12 = 2 THEN ' + CAST(@StartHR AS VARCHAR(3)) + ' + ROUND((' + CAST(@EndHR AS VARCHAR(3))  + ' - ' + CAST(@StartHR AS VARCHAR(3)) + ') *  (CAST((Id - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ') AS DECIMAL(6,3))/(' + CAST(@EndFixHRId AS VARCHAR(10)) + ' - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ')),0.1) -2
					WHEN DATEPART(second,MovingTime) % 12 = 3 THEN ' + CAST(@StartHR AS VARCHAR(3)) + ' + ROUND((' + CAST(@EndHR AS VARCHAR(3))  + ' - ' + CAST(@StartHR AS VARCHAR(3)) + ') *  (CAST((Id - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ') AS DECIMAL(6,3))/(' + CAST(@EndFixHRId AS VARCHAR(10)) + ' - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ')),0.1) -3
					WHEN DATEPART(second,MovingTime) % 12 = 4 THEN ' + CAST(@StartHR AS VARCHAR(3)) + ' + ROUND((' + CAST(@EndHR AS VARCHAR(3))  + ' - ' + CAST(@StartHR AS VARCHAR(3)) + ') *  (CAST((Id - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ') AS DECIMAL(6,3))/(' + CAST(@EndFixHRId AS VARCHAR(10)) + ' - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ')),0.1) -2
					WHEN DATEPART(second,MovingTime) % 12 = 5 THEN ' + CAST(@StartHR AS VARCHAR(3)) + ' + ROUND((' + CAST(@EndHR AS VARCHAR(3))  + ' - ' + CAST(@StartHR AS VARCHAR(3)) + ') *  (CAST((Id - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ') AS DECIMAL(6,3))/(' + CAST(@EndFixHRId AS VARCHAR(10)) + ' - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ')),0.1) -1
					WHEN DATEPART(second,MovingTime) % 12 = 6 THEN ' + CAST(@StartHR AS VARCHAR(3)) + ' + ROUND((' + CAST(@EndHR AS VARCHAR(3))  + ' - ' + CAST(@StartHR AS VARCHAR(3)) + ') *  (CAST((Id - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ') AS DECIMAL(6,3))/(' + CAST(@EndFixHRId AS VARCHAR(10)) + ' - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ')),0.1)
					WHEN DATEPART(second,MovingTime) % 12 = 7 THEN ' + CAST(@StartHR AS VARCHAR(3)) + ' + ROUND((' + CAST(@EndHR AS VARCHAR(3))  + ' - ' + CAST(@StartHR AS VARCHAR(3)) + ') *  (CAST((Id - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ') AS DECIMAL(6,3))/(' + CAST(@EndFixHRId AS VARCHAR(10)) + ' - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ')),0.1) -1
					WHEN DATEPART(second,MovingTime) % 12 = 8 THEN ' + CAST(@StartHR AS VARCHAR(3)) + ' + ROUND((' + CAST(@EndHR AS VARCHAR(3))  + ' - ' + CAST(@StartHR AS VARCHAR(3)) + ') *  (CAST((Id - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ') AS DECIMAL(6,3))/(' + CAST(@EndFixHRId AS VARCHAR(10)) + ' - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ')),0.1) -2
					WHEN DATEPART(second,MovingTime) % 12 = 9 THEN ' + CAST(@StartHR AS VARCHAR(3)) + ' + ROUND((' + CAST(@EndHR AS VARCHAR(3))  + ' - ' + CAST(@StartHR AS VARCHAR(3)) + ') *  (CAST((Id - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ') AS DECIMAL(6,3))/(' + CAST(@EndFixHRId AS VARCHAR(10)) + ' - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ')),0.1) -3
					WHEN DATEPART(second,MovingTime) % 12 = 10 THEN ' + CAST(@StartHR AS VARCHAR(3)) + ' + ROUND((' + CAST(@EndHR AS VARCHAR(3))  + ' - ' + CAST(@StartHR AS VARCHAR(3)) + ') *  (CAST((Id - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ') AS DECIMAL(6,3))/(' + CAST(@EndFixHRId AS VARCHAR(10)) + ' - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ')),0.1) -2
					WHEN DATEPART(second,MovingTime) % 12 = 11 THEN ' + CAST(@StartHR AS VARCHAR(3)) + ' + ROUND((' + CAST(@EndHR AS VARCHAR(3))  + ' - ' + CAST(@StartHR AS VARCHAR(3)) + ') *  (CAST((Id - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ') AS DECIMAL(6,3))/(' + CAST(@EndFixHRId AS VARCHAR(10)) + ' - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ')),0.1) -1
					WHEN DATEPART(second,MovingTime) % 12 = 0 THEN ' + CAST(@StartHR AS VARCHAR(3)) + ' + ROUND((' + CAST(@EndHR AS VARCHAR(3))  + ' - ' + CAST(@StartHR AS VARCHAR(3)) + ') *  (CAST((Id - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ') AS DECIMAL(6,3))/(' + CAST(@EndFixHRId AS VARCHAR(10)) + ' - ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ')),0.1)
					ELSE ' + CAST(@EndHR AS VARCHAR(3)) + ' 
				END, 
				IsAdjustHR = 1 
				FROM [Strava].[dbo].' + @TableName + '
				WHERE Id >= ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + '
				AND Id < ' + CAST(@EndFixHRId AS VARCHAR(10)) + ';';

				PRINT @SQL;

				EXEC sp_executesql @SQL;

			END

		END

	END TRY
	BEGIN CATCH

		SET @ErrorMessage  = ERROR_MESSAGE();
		SET @ErrorSeverity = ERROR_SEVERITY();
		SET @ErrorState    = ERROR_STATE();

		RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);

	END CATCH

END