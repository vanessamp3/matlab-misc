%--------------------------------------------------------------------------
% Name : /home/vpalzes/NAPLS/NAPLS3_evalQA.m
%
% Author : Vanessa Palzes
%
% Creation Date : 6/25/2015
%
% Purpose : This will run on all downloaded data, which should be in
% /home/bjr39/mathalon/Delta/napls3/bdf and beh, as well as in the SQL
% tables. Although my download script should alert us of issues via email,
% we may want to run this to evaluate all of the data periodically to make
% sure we are capturing the discrepancies.
%
% The discrepancies will be added to the table "qa_issues" and we can mark
% whether or not they were acknowledged or resolved.
%
% Usage : NAPLS3_evalQA
%
% Inputs : None
%
% Outputs: An emailed report of unresolved issues.
%
% Last modified: 6/25/2015
%--------------------------------------------------------------------------

clc;

warning('off','all');

mysql('open','localhost','root','denali','NAPLS3');

% Site names
SITE_NAMES = {'UCLA'; 'Emory'; 'Harvard'; 'Hillside'; 'UNC'; 'UCSD'; 'Calgary'; 'Yale'; 'UCSF'};

% Directories
bdf_path = '/home/bjr39/mathalon/Delta/napls3/bdfs/';
beh_path = '/home/bjr39/mathalon/Delta/napls3/beh/';
issues_path = '/home/bjr39/mathalon/Delta/napls3/zips/issues/';

% LTP tasks
ltp = {'hv1'; 'hv2'; 'hv3'; 'hv4'; 'HFS'; 'comMMN'};
harmonization = {'aod'; 'mmn'};

%%%%% CHECK BDFS %%%%%
% Check for date mismatches
query = 'SELECT * FROM bdf_info WHERE date_match!=1;';
result = mysql(query);

for i = 1:length(result)
    
    % Get data from SQL query result
    sessionid = result(i).sessionid;
    bdf_name = result(i).bdf_name;
    bdfid = result(i).bdfid;
    filedate = result(i).date_created;
    
    % Get paradigm info
    presult = mysql(['SELECT * FROM paradigms WHERE bdfid=' num2str(bdfid) ';']);
    table = presult.table;
    
    % Get session info
    query = ['SELECT * FROM ' table ' WHERE sessionid="' sessionid '";'];
    tresult = mysql(query);
    
    % Get the visitdate and site from query result
    formdate = tresult.visitdate;
    site = tresult.site;
    
    if result(i).date_match==0
        msg = ['date mismatch (created: ' filedate ', entered: ' formdate ')'];
    else
        msg = 'could not determine date from header';
    end
    
    % Add error to QA issues table
    add2table(site, bdf_name, msg);
    
end

% Check for weird filesizes
query = ['SELECT sessionid, bdf_info.bdfid, bdf_name, bdf_info.filesize AS actual, '...
    'paradigms.filesize AS expected, `table`, `col`, num_runs, '...
    'bdf_info.filesize-paradigms.filesize AS difference FROM bdf_info INNER JOIN paradigms ON (bdf_info.bdfid=paradigms.bdfid);'];
result = mysql(query);
diffs = {result.difference}';
diffs = cell2mat(diffs);
idx = find(abs(diffs)>10);
for i = 1:length(idx)
    
    % Current file
    this_file = result(idx(i));
    
    % Query session info
    query = ['SELECT site, ' this_file.col ' FROM ' this_file.table ' WHERE sessionid="' this_file.sessionid '";'];
    tresult = mysql(query);
    
    % Check if it is an HFS file
    if strcmp(this_file.col,'hfs')
        if ~isempty(tresult.hfs)
            tresult.hfs = 1;
        else
            tresult.hfs = 0;
        end
    end
    
    % Check filesize against standard
    if this_file.num_runs == eval(['tresult.' this_file.col])
        this_file.actual = num2str(this_file.actual,'%0.2f');
        this_file.expected = num2str(this_file.expected,'%0.2f');
        msg = ['unexpected filesize (actual: ' num2str(this_file.actual) ', expected: ' num2str(this_file.expected) ')'];
        add2table(tresult.site, this_file.bdf_name, msg);
    end
    
end

% Check for other issues
issues = dir(issues_path);
issues = issues(3:end);
for i = 1:length(issues)
   if issues(i).isdir == 1
       parts = strsplit('_',issues(i).name);
       site = str2double(parts{1});
       
       msg = 'could not download data (likely missing headers)';
       add2table(site, issues(i).name, msg);
   end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%% CHECK LOGS %%%%%
% Check for date mismatches
query = 'SELECT * FROM log_info WHERE date_match!=1;';
result = mysql(query);
    
for i = 1:length(result)
    
    % Get info from query
    sessionid = result(i).sessionid;
    log_name = result(i).log_name;
    filedate = result(i).date_created;
    
    % Get session info
    tresult = mysql(['SELECT * FROM ltp WHERE sessionid="' sessionid '";']);    
    formdate = tresult.visitdate;
    site = tresult.site;
    
    if result(i).date_match==0
        msg = ['date mismatch (created: ' filedate ', entered: ' formdate ')'];
    else
        msg = 'could not determine date from header';
    end
    
    % Add error to QA issues table
    add2table(site, log_name, msg);
    
end

% Check for scenario/filename discrepancies
query = 'SELECT * FROM log_info WHERE log_match!=1;';
result = mysql(query);

for i = 1:length(result)
    
    % Get info from query
    log_name = result(i).log_name;
    scenario = result(i).scenario;
    site = str2int(result(i).sessionid(1:2));
    
    % If the filename is not as expected, create an error
    if result(i).log_match==0
        msg = ['incorrect scenario run (' scenario ')'];
    else
        msg = 'could not determine scenario from logfile';
    end
    
    % Add error to QA issues table
    add2table(site, log_name, msg);
end

% Check for quit logfiles (and we don't have another complete logfile for
% the scenario)
% Now let's check for QUIT logfiles and make sure we have another scenario
% that was not quit
query = 'SELECT distinct(sessionid) FROM log_info WHERE quit!=0 AND log_name NOT LIKE "%instructions%";';
result = mysql(query);

for i = 1:length(result)
    
    sessionid = result(i).sessionid;
    
    % Get site and HFS info
    sess = mysql(['SELECT site, hfs FROM ltp WHERE `sessionid`="' sessionid '";']);
    site = sess.site;
    hfs = sess.hfs;
    
    % Get list of quit logs
    quitlogs = mysql(['SELECT * FROM log_info WHERE `sessionid`="' sessionid '" AND `quit`=1 AND log_name NOT LIKE "%instructions%";']);
    quitscens = {quitlogs.scenario}';
    [quitscens, ~, quitidx] = unique(quitscens);
    for j = 1:length(quitscens)
        
        % Sometimes people will start running Horizontal, but it should be
        % Vertical, or vice versa. Ignore these logfiles!
        if (~isempty(strfind(quitscens{j},'Horizontal')) && strcmp(hfs,'V')) || (~isempty(strfind(quitscens{j},'Vertical')) && strcmp(hfs,'H'))
            continue;
        end
        
        qresult = mysql(['SELECT * FROM log_info WHERE `sessionid`="' sessionid '" AND `scenario`="' quitscens{j} '" AND `quit`=0;']);
        if isempty(qresult)
            msg = ['no complete logfile for scenario ' quitscens{j}];
            add2table(site, quitlogs(quitidx(j)).log_name, msg);
        end
    end
    
    % Check for blank logfiles
    blanklogs = mysql(['SELECT * FROM log_info WHERE `sessionid`="' sessionid '" AND `quit`=-1;']);
    for j=1:length(blanklogs)
        msg = 'could not read logfile';
        add2table(site, blanklogs(j).log_name, msg);
    end
    
end
end
%%%%%%%%%%%%%%

%%% FUNCTIONS %%%
function add2table(site, filename, errmsg)
% This function will check the qa_issues table and add a row if the
% filename doesn't already have that error added
    
    result = mysql(['SELECT * FROM qa_issues WHERE filename="' filename '" AND errmsg="' errmsg '";']);
    
    if isempty(result)
        mysql(['INSERT INTO qa_issues (site, filename, errmsg, acknowledged, resolved) VALUES (' num2str(site) ', "' filename '", "' errmsg '", 0, 0);']);
    end
end
    
