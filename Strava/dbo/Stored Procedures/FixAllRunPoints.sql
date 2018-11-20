CREATE PROCEDURE dbo.FixAllRunPoints
(
	@GPXFilename VARCHAR(1000),
	@RunDate VARCHAR(8) = NULL,
	@RunName VARCHAR(500) = NULL,
	@StopTime TINYINT = 60,
	@AddMinutesToAllPoints SMALLINT = 0,
	@IsDeleteAndRecreateTables TINYINT = 0,
	@IsAdjustHR TINYINT = 0,
	@Debug TINYINT = 0
)
AS
BEGIN

	SET NOCOUNT ON;

	BEGIN TRY

		DECLARE @ErrorMessage NVARCHAR(MAX),
				@ErrorSeverity INT,
				@ErrorState INT;

		DECLARE @MovingTime TIME,
				@TableName VARCHAR(100),
				@LoopCounter INT = 1,
				@NumPoints INT,
				@SQL NVARCHAR(2000);

		CREATE TABLE #PointsToBeCorrected
		(
			Id INT IDENTITY(1,1) NOT NULL,
			MovingTime TIME NOT NULL
		);

		IF @RunDate IS NULL
			SELECT @RunDate = FORMAT(GETDATE(), 'yyyyMMdd');

		IF @RunName IS NULL AND @RunDate IS NOT NULL
			SELECT @RunName = REPLACE(REPLACE(REPLACE(@GPXFilename,'it_s_','it''s '),'_',' '),'.gpx','');

		IF @Debug = 1
			SELECT @GPXFilename AS GPXFilename, @RunDate AS RunDate;

		EXEC dbo.CreateAndLoadGPXFile 
		@GPXFilename = @GPXFilename, 
		@RunDate = @RunDate,
		@IsDeleteAndRecreateTables = @IsDeleteAndRecreateTables,
		@TableName = @TableName OUTPUT,
		@Debug= @Debug;

		IF @AddMinutesToAllPoints <> 0
		BEGIN

			SET @SQL = 
			'UPDATE ' + @TableName + '
			SET [Time] = DATEADD(mi,' + CAST(@AddMinutesToAllPoints AS NVARCHAR(5)) + ',[Time]), PreviousTime = DATEADD(mi,' + CAST(@AddMinutesToAllPoints AS NVARCHAR(5)) + ',PreviousTime);';

			IF @Debug = 1
				PRINT @SQL;

			EXEC sp_executesql @SQL;

		END

		IF @Debug = 1
			SELECT @TableName AS TableName;

		SET @SQL = 
		'INSERT INTO #PointsToBeCorrected
		(MovingTime)
		SELECT MovingTime
		FROM ' + @TableName + '
		WHERE DiffTime > ' + CAST(@StopTime AS NVARCHAR(3)) + '
		ORDER BY MovingTime DESC;';

		IF @Debug = 1
			PRINT @SQL;

		EXEC sp_executesql @SQL;

		SELECT @NumPoints = COUNT(1)
		FROM #PointsToBeCorrected;

		IF @Debug = 1
		BEGIN

			SELECT *
			FROM #PointsToBeCorrected
			ORDER BY Id;

			SELECT @NumPoints AS NumPoints;

		END

		SET @LoopCounter = 1;

		WHILE @LoopCounter <= @NumPoints
		BEGIN

			SELECT @MovingTime = MovingTime
			FROM #PointsToBeCorrected
			WHERE Id = @LoopCounter;

			IF @Debug = 1
				SELECT @LoopCounter AS LoopCounter, @MovingTime AS MovingTime;

			EXEC dbo.RemoveRunPointsAndAdjustRemainingRunPoints
			@TableName = @TableName,
			@StartDeleteMovingTime = @MovingTime,
			@EndDeleteMovingTime = @MovingTime,
			@IsAdjustHR = @IsAdjustHR,
			@Debug = @Debug;

			SET @LoopCounter = @LoopCounter + 1;

		END

		IF @Debug = 1
			SELECT @TableName AS TableName, @RunName AS RunName;

		EXEC dbo.OutputRunGPX
		@Tablename = @TableName,
		@RunName = @RunName,
		@Debug= @Debug;

	END TRY
	BEGIN CATCH

		SET @ErrorMessage  = ERROR_MESSAGE();
		SET @ErrorSeverity = ERROR_SEVERITY();
		SET @ErrorState    = ERROR_STATE();

		RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);

	END CATCH

END