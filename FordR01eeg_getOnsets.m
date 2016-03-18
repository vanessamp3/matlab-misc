function cout = FordR01eeg_getOnsets(beh_file)
%--------------------------------------------------------------------------
% Name : /home/vpalzes/scripts/FordR01fmri/FordR01eeg_getOnsets.m
% 
% Author : Vanessa Palzes
% 
% Creation Date : 12/29/2015
% 
% Purpose : Extracts the onsets for Ford R01 eeg delay data.
% Reads in the subject's behavioral file. The onsets are returned in seconds.
%
% Usage : onsets = FordR01eeg_getOnsets(beh_file)
%	where beh_file is a behavioral log file for a run for the subject.
%	beh_file = '/home/tle6/data/behavioral/R32004/R32004eeg-fordR01delayBlockA.log
%
% Inputs :
%   beh_file = a cell array of behavioral log files
%
% Outputs : 
%   Returns the onsets in a struct format as cout. The blocks will
%   be rest, toneself, toneplay, checkself, checkplay, and controlself. The events
%   will have an '_event' appended to the field name.
%
% Revision Notes:
% 1/21/2016 - The script was not picking up the first rest
% block, which is presumably OK because it is part of the implicit baseline
% anyway. I also added a check to make sure there are no presses during rest 
% blocks. If there are, then I will get an email.
%--------------------------------------------------------------------------

% Load the beh file
global log;
log = read_presentation_log2(beh_file);

% Find the attenuation level
for i = 1:length(log)
    if strcmp(log{i,3}, 'Text Input')
        cout.attenuation = str2num(log{i,4});
        break;
    end
end

% Find the first scan pulse onset
for i = 1:length(log)
    if strcmp(log{i,3}, 'Pulse')
        expStart = log{i,5};
        break;
    end
end

% Initialize the arrays
cout.rest.ons = [];
cout.rest.dur = [];

cout.toneself.ons = [];
cout.toneself.dur = [];
cout.toneself_event.ons = [];

cout.checkself.ons = [];
cout.checkself.dur = [];
cout.checkself_event.ons = [];

cout.toneplay.ons = [];
cout.toneplay.dur = [];
cout.toneplay_event.ons = [];

cout.checkplay.ons = [];
cout.checkplay.dur = [];
cout.checkplay_event.ons = [];

cout.controlself.ons = [];
cout.controlself.dur = [];
cout.controlself_event.ons = [];
controlself_block_idx = [];

mailstr = '';

% Loop through each line in the beh file
for e = i:size(log,1)
    
    % Find event type
    event = log{e,3};
    
    % Find code
    code = log{e,4};
    if isnumeric(code)
        code = num2str(code);
    end
    
    % Get duration
    duration = log{e,8} / 20000;
    
    % Get time
    time = (log{e,5} - expStart) / 20000;
    % Presentation times are in 10000 / sec and there is a 2 sec TR
    
    % If this is the first pulse, then this is the first resting block
    if log{e,5} == expStart
        % Look ahead 15 lines to find the start of the next press block
        for line = e:e+15
            if strcmp(log{line,4},'PRESS_Cue11')
                duration = (log{line,5} - expStart) / 20000;
                break;
            end
        end
        code = 'rest12';
    end
    
    %%% BLOCK DESIGN CODES %%%
    if strcmp(code,'rest12') % rest block
        cout.rest.ons = [cout.rest.ons time];
        cout.rest.dur = [cout.rest.dur duration];
        
        % Make sure there are no presses in a rest block (eek!)
        count = 0;
        for line = e:e+20
            if line < length(log)
                if ~isempty(strfind(log{line,4},'PRESS')) || ~isempty(strfind(log{line,4},'LISTEN'))
                    break;
                elseif strcmp(log{line,3},'Response')
                    count = count+1;
                end
            end
        end
        if count > 0
            cprintf('err', 'Subject pressed %i times during rest block\n', count);
            mailstr = sprintf('%sERROR - Subject pressed %i times during rest block (%s)\n', mailstr, count, beh_file);
        end
        
    elseif strcmp(code,'PRESS_Cue11')
        % Look ahead 10 lines to see what type of press block this is
        pressType = '';
        for line = e:e+10
            if strcmp(log{line,4},'self tone')
                pressType = 'toneself';
                break;
            elseif strcmp(log{line,4},'self check')
                pressType = 'checkself';
                break;
            end
        end
        if strcmp(pressType,'')
            for line = e:e+10
                if strcmp(log{line,4},'20')
                    pressType = 'controlself';
                    break;
                end
            end
        end
        
        % If it's a controlself block, then enter onset and duration
        if strcmp(pressType,'controlself')
            cout.(pressType).ons = [cout.(pressType).ons time];
            cout.(pressType).dur = [cout.(pressType).dur duration];
            controlself_block_idx = [controlself_block_idx e];
        % If it's a toneself or checkself block, then need to look up the duration
        elseif strcmp(pressType,'toneself') || strcmp(pressType,'checkself')
            cout.(pressType).ons = [cout.(pressType).ons time];
            cout.(pressType).dur = [cout.(pressType).dur findDuration(e)];
        end
        
    elseif strcmp(code,'1stLISTEN_CUE') || strcmp(code,'1stWATCH_CUE')
        % Look ahead 10 lines to see what type of listen block this is
        pressType = '';
        for line = e:e+10
            if strcmp(log{line,4},'play tone')
                pressType = 'toneplay';
                break;
            elseif strcmp(log{line,4},'play check')
                pressType = 'checkplay';
                break;
            end
        end
        if strcmp(pressType,'toneplay') || strcmp(pressType,'checkplay')
            cout.(pressType).ons = [cout.(pressType).ons time];
            cout.(pressType).dur = [cout.(pressType).dur findDuration(e)];
        end
        
    
    %%% EVENT DESIGN CODES %%%
    elseif strcmp(event, 'Sound') && strcmp(code, 'self tone')
        cout.toneself_event.ons = [cout.toneself_event.ons time];
        
    elseif strcmp(event, 'Picture') && strcmp(code, 'self check')
        cout.checkself_event.ons = [cout.checkself_event.ons time];
        
    elseif strcmp(event, 'Sound') && strcmp(code, 'play tone')
        cout.toneplay_event.ons = [cout.toneplay_event.ons time];
        
    elseif strcmp(event, 'Picture') && strcmp(code, 'play check')
        cout.checkplay_event.ons = [cout.checkplay_event.ons time];        
    end
    
end

% Find controlself events
for b = 1:length(controlself_block_idx)
    line = controlself_block_idx(b);
    for i = line+1:line+40
        code = log{i,4};
        if isnumeric(code)
            code = num2str(code);
        end
        time = (log{i,5} - expStart) / 20000;
        if strcmp(code,'20') && strcmp(log{i,3},'Response')
            cout.controlself_event.ons = [cout.controlself_event.ons time];
        elseif strcmp(log{i,3},'Picture') && strcmp(log{i,4},'rest12')
            break;
        end
    end
end

% Get number of events per block
fields = {'toneself';'checkself';'toneplay';'checkplay';'controlself'};
for f = 1:length(fields)
    
    % Get number of events overall for the task
    taskEvents = cout.([fields{f} '_event']);
    numEvents = length(taskEvents.ons);
    
    % Get task blocks
    task = cout.(fields{f});
    cout.(fields{f}).num = zeros(1,length(task.ons));
    
    % Loop through events and determine which block they belong to
    for e = 1:numEvents
        for b = 1:length(task.ons)
            curEvent = taskEvents.ons(e);
            startBlock = task.ons(b);
            endBlock = task.ons(b) + task.dur(b);
            if curEvent > startBlock && curEvent < endBlock
                cout.(fields{f}).num(b) = cout.(fields{f}).num(b) + 1;
            end
        end
    end
    
    % If any blocks were found without events, can't determine what block
    % onset was, so just fill remaining blocks with zeros
    if length(task.ons)<3
        for b = 1:(3-length(task.ons))
            cout.(fields{f}).ons = [cout.(fields{f}).ons 0];
            cout.(fields{f}).dur = [cout.(fields{f}).dur 0];
            cout.(fields{f}).num = [cout.(fields{f}).num 0];
        end
    end
    
end

% Mailing for errors
system(['ssh bieeglne@www.bieegl.net ''echo -e "' mailstr '" | /bin/mail -s "FordR01eeg Behavioral Issue" "vanessa.palzes@ncire.org"''']);


% Determine the duration for the toneself and toneplay blocks because the
% duration in the logfile is split across the different Picture events. The
% duration can be calculated by determine the time the next rest period
% starts and then subtracting the start time of the block.
function duration = findDuration(line)
global log;

startTime = log{line,5};

% Find the next rest block
for i = line:line+100 
    if strcmp(log{i,4},'rest12')
        endTime = log{i,5};
        break;
    end    
end

% Calculate duration, time should be TRs
duration = (endTime - startTime) / 20000;