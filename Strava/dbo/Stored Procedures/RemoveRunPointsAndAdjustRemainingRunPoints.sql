CREATE PROCEDURE dbo.RemoveRunPointsAndAdjustRemainingRunPoints
(
	@TableName VARCHAR(100),
	@StartDeleteMovingTime TIME,
	@EndDeleteMovingTime TIME,
	@IsAdjustHR TINYINT = 0,
	@IsNoMaxHR TINYINT = 0,
	@HRTimeLimitAfterStop INT = 300,
	@Debug TINYINT = 0
)
AS
BEGIN

	SET NOCOUNT ON;

	BEGIN TRY

		DECLARE @StartDeleteTimeId INT,
				@EndDeleteTimeId INT,
				--@EndHRTimeId INT,
				@StartDeleteTime DATETIME,
				@EndDeleteTime DATETIME,
				@StartHR INT,
				@EndHR INT,
				--@FixHR INT,
				@TimeAddedAfterStopIds INT,
				--@NextIdOfSameHR INT,
				@EndFixHRId INT,
				@DiffTime INT,
				@SQL NVARCHAR(2000);

		DECLARE @ErrorMessage NVARCHAR(MAX),
				@ErrorSeverity INT,
				@ErrorState INT;

		IF OBJECT_ID('tempdb..#RunPointsTable') IS NOT NULL
			DROP TABLE #RunPointsTable;

		--Create temp table to hold the run table data so don't have to keep using dynamic sql
		CREATE TABLE #RunPointsTable
		(
			Id INT NOT NULL,
			Lat DECIMAL(20,12) NOT NULL,
			Lon DECIMAL(20,12) NOT NULL,
			Ele DECIMAL(5,2) NULL,
			[Time] DATETIME NOT NULL,
			HR INT NULL,
			CAD INT NULL,
			PreviousLat DECIMAL(20,12) NULL,
			PreviousLon DECIMAL(20,12) NULL,
			PreviousTime DATETIME NULL,
			DiffLat DECIMAL(20,12) NULL,
			DiffLon DECIMAL(20,12) NULL,
			DiffTime INT NULL,
			Dist DECIMAL(20,12) NULL,
			MovingTime TIME(7) NULL,
			Geog GEOGRAPHY NULL,
			IsAdjustPoint TINYINT NULL DEFAULT 0,
			NumAdjustPoints TINYINT NULL DEFAULT 0,
			IsHRAdjusted TINYINT DEFAULT 0
			PRIMARY KEY CLUSTERED 
			(
				[Id] ASC
			)
		);

		SET @SQL = 'INSERT INTO #RunPointsTable SELECT * FROM dbo.' + @TableName;
		EXEC sp_executesql @SQL;

		IF @Debug = 1
			PRINT @SQL;

		SELECT @StartDeleteTimeId = Id, @StartDeleteTime = [Time] FROM #RunPointsTable WHERE MovingTime = @StartDeleteMovingTime;
		SELECT @EndDeleteTimeId = Id, @EndDeleteTime = [Time] FROM #RunPointsTable WHERE MovingTime = @EndDeleteMovingTime;

		IF @Debug = 1
		BEGIN

			SELECT @StartDeleteTimeId AS StartDeleteTimeId, @StartDeleteTime AS StartDeleteTime, @StartDeleteMovingTime AS StartDeleteMovingTime;
			SELECT @EndDeleteTimeId AS EndDeleteTimeId, @EndDeleteTime AS EndDeleteTime, @EndDeleteMovingTime AS EndDeleteMovingTime;

			IF @IsAdjustHR = 1
				SELECT @EndFixHRId AS EndFixHRId, @EndFixHRId AS EndFixHRId, @StartHR AS StartHR, @EndHR AS EndHR;

			--SELECT @NextIdOfSameHR AS NextIdOfSameHR;

			SELECT 'Points to be deleted';

			SELECT *
			FROM #RunPointsTable
			WHERE Id > @StartDeleteTimeId
			AND Id <= @EndDeleteTimeId;

			--SELECT *
			--FROM #RunPointsTable;

		END

		--Delete rows between start and end delete times if any portion of the run is to be deleted
		SET @SQL = '
		DELETE
		FROM [Strava].[dbo].' + @TableName + '
		WHERE Id > ' + CAST(@StartDeleteTimeId AS VARCHAR(10)) + '
		AND Id <= ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ';';

		IF @Debug = 1
			PRINT @SQL;

		EXEC sp_executesql @SQL;

		SELECT @DiffTime = DATEDIFF(s,@EndDeleteTime,@StartDeleteTime);

		--If the times selected are the same time then correct the difftime (no deleted points, but want to adjust the time because of a stoppage)
		IF @DiffTime = 0
			SELECT @DiffTime = (0 - DiffTime) + 1 FROM #RunPointsTable WHERE Id = @StartDeleteTimeId;

		IF @Debug = 1
		BEGIN

			SELECT @DiffTime AS DiffTime;

			SELECT 'PreviousTime to be updated';
			
			SELECT Id, [Time]
			FROM #RunPointsTable
			WHERE Id = @StartDeleteTimeId;

			SELECT 'Rows to be date adjusted';

			SELECT *, [NewTime] = DATEADD(s,@DiffTime,[Time]),[NewPreviousTime] = DATEADD(s,@DiffTime,[PreviousTime])
			FROM #RunPointsTable
			WHERE Id >= @EndDeleteTimeId;

		END

		--Adjust all the rows after the end delete time to move all the points a second after the start delete point
		SET @SQL = '
		UPDATE [Strava].[dbo].' + @TableName + '
		SET [Time] = DATEADD(s,' + CAST(@DiffTime AS VARCHAR(10)) + ',[Time]), 
		IsAdjustPoint = 
		CASE 
			WHEN Id = ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ' AND IsAdjustPoint = 0 THEN 1
			WHEN IsAdjustPoint = 1 THEN 1
			ELSE 0
		END,
		NumAdjustPoints = NumAdjustPoints + 1
		WHERE Id >= ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ';';

		IF @Debug = 1
			PRINT @SQL;

		EXEC sp_executesql @SQL;

		--Update the PreviousLat, PreviousLon, and PreviousTime columns for the time adjusted rows
		SET @SQL = '
		;WITH Previous AS
		(
			SELECT Id, PreviousLat = LAG(Lat,1) OVER (ORDER BY Id), PreviousLon = LAG(Lon,1) OVER (ORDER BY Id), PreviousTime = LAG([Time],1) OVER (ORDER BY Id)
			FROM [Strava].[dbo].' + @TableName + '
			WHERE Id >= ' + CAST(@EndDeleteTimeId AS VARCHAR(10)) + ' - 1
		)
		UPDATE r
		SET PreviousLat = prev.PreviousLat, PreviousLon = prev.PreviousLon, PreviousTime = prev.PreviousTime
		FROM [Strava].[dbo].' + @TableName + ' r
		INNER JOIN Previous prev
		ON r.Id = prev.Id
		WHERE r.Id >= ' +  CAST(@EndDeleteTimeId AS VARCHAR(10)) + ';'


		IF @Debug = 1
			PRINT @SQL;

		EXEC sp_executesql @SQL;

		--Update DiffLat, DiffLon, DiffTime, and MovingTime for all rows after end delete time
		SET @SQL = '
		UPDATE [Strava].[dbo].' + @TableName + '
		SET DiffLat = Lat - PreviousLat, 
		DiffLon = Lon - PreviousLon, 
		DiffTime = DATEDIFF(s, PreviousTime, [Time]),
		MovingTime = CAST(DATEADD(s,Id,''00:00.00'') AS TIME(0))
		WHERE Id >= ' +  CAST(@EndDeleteTimeId AS VARCHAR(10)) + ';'

		IF @Debug = 1
			PRINT @SQL;

		EXEC sp_executesql @SQL;

		--IF @IsAdjustHR = 1 AND @EndFixHRId IS NOT NULL
		IF @IsAdjustHR = 1 AND @EndFixHRId IS NOT NULL
		BEGIN

			EXEC dbo.AdjustHRRunPoints
			@TableName = @TableName,
			@StartDeleteMovingTime = @StartDeleteMovingTime,
			@EndDeleteMovingTime = @EndDeleteMovingTime,
			@StartDeleteTime = @StartDeleteTime,
			@EndDeleteTime = @EndDeleteTime,
			@HRTimeLimitAfterStop = @HRTimeLimitAfterStop,
			@Debug = @Debug;

		END

	END TRY
	BEGIN CATCH

		SET @ErrorMessage  = ERROR_MESSAGE();
		SET @ErrorSeverity = ERROR_SEVERITY();
		SET @ErrorState    = ERROR_STATE();

		RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);

	END CATCH

END