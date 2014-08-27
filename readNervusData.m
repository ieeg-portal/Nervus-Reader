function [hdr, data] = readNervusData(filename, startIndex, lData, channels)
  % READNICEEG  Reads Nervus .eeg files (not bni-1 or bni-2).
  %
  %   HDR = READNICEEG(FILENAME) returns header information for file.
  %
  %   [HDR, DATA] = READNICEEG(FILENAME, STARTINDEX, LENGTH, CHANNELS)
  %   returns the header information and the requested data.
  %
  %
  % Annotations are stored in this format but not annotations that are
  % created in the Nicolet viewer. These are probably stored locally in a
  % database.
  
  % Author: J.B Wagenaar
  %
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % Copyright 2013 Trustees of the University of Pennsylvania
  % 
  % Licensed under the Apache License, Version 2.0 (the "License");
  % you may not use this file except in compliance with the License.
  % You may obtain a copy of the License at
  % 
  % http://www.apache.org/licenses/LICENSE-2.0
  % 
  % Unless required by applicable law or agreed to in writing, software
  % distributed under the License is distributed on an "AS IS" BASIS,
  % WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  % See the License for the specific language governing permissions and
  % limitations under the License.
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
  narginchk(1,4);
  nargoutchk(1, 2);
  
  BYTESPERVALUE = 2;
  
  switch nargin
    case 1
      assert(nargout ==1, 'Incorrect number of output arguments.');
      returnData = false;
    case 4      
      assert(nargout ==2, 'Incorrect number of output arguments.');
      returnData = true;
    otherwise
      error('Incorrect number of input arguments.');
  end
  
  h = fopen(filename,'r','ieee-le');

  fseek(h, 208,'bof');
  path = fread(h, 30, '*char'); %#ok<NASGU> Unused ---> no sense to return.
  
  
  hdr = struct(...
    'startDate',[],...
    'startTime',[],...
    'endDate',[],...
    'endTime',[],...
    'samplingRate',0,...
    'nrTraces',0,...
    'nrChannels',0,...
    'nrValues',0,...
    'chanInfo',struct(),...
    'annotations',struct(),...
    'montage',struct(),...
    'sections',struct(),...
    'locs',struct());
    
  
  % Find Sections in File
  fseek(h, 336, 'bof');
  nrSec = fread(h,1,'*int16');
  sections = struct('name','','id',0,'l',0,'rec',0);
  for i = 1: nrSec
    sections(i).name = fread(h,10,'*char');
    unknown1 = fread(h,1,'*uint16');
    sections(i).id = fread(h,1,'*uint16');
    sections(i).l = fread(h,1,'*uint16');
    sections(i).rec = fread(h,1,'*uint32');
    unknown2 = fread(h,2,'*uint16');
  end
  hdr.sections = sections;
    
  % Get locations in file for sections.
  fseek(h, 24914,'bof');
  unknown3 = fread(h,1,'*int32'); 
  
  nSec= fread(h,1,'*int16');
  locs = struct('id',[],'start',[],'length',[]);
  for i = 1: nSec
    locs(i).id = fread(h,1,'*int16');
    locs(i).start = fread(h,1,'*int32');
    locs(i).length = fread(h,1,'*int32');
  end
  hdr.locs = locs;
  
  allIDs = [locs.id];
  
  % Get Start date/time for file --> ID = 0
  zeroIdx = find(allIDs==0,1);
  fseek(h, locs(zeroIdx).start,'bof');
  
  hdr.startTime = fread(h, 3,'uint16')';
  hdr.startTime = hdr.startTime(end:-1:1);
  hdr.startDate = fread(h, 3,'uint16')';
  unknown4 = fread(h, 3,'uint16'); 
  hdr.endTime = fread(h, 3,'uint16')';
  hdr.endTime = hdr.endTime(end:-1:1);
  hdr.endDate = fread(h, 3,'uint16')';
  unknown5 = fread(h, 3,'uint16'); 
  
  % Find Labels --> ID = 1
  oneIdx = find(allIDs==1,1);
  
  labelOffset = locs(oneIdx).start;
  fseek(h, labelOffset,'bof');
  
  hdr.samplingRate = fread(h, 1, 'int16');
  hdr.nrTraces = fread(h, 1, 'int16');
  hdr.nrChannels = fread(h, 1, 'int16');
  
  chanInfo = struct('name','','reference','','mult',0);
  for iChan = 1: hdr.nrTraces
    chanInfo(iChan).name = deblank(fread(h, 6, '*char')');
    chanInfo(iChan).unknown1 = fread(h, 1, 'uint16');
    chanInfo(iChan).reference = deblank(fread(h, 6, '*char')');
    chanInfo(iChan).mult = fread(h, 1, '*single');
    
    chanInfo(iChan).misc1 = fread(h, 7, 'uint16');
    chanInfo(iChan).conv = fread(h,1,'single');

    chanInfo(iChan).misc2 = fread(h,3,'single');
  end
  hdr.chanInfo = chanInfo;
  
  % Get Sensor information --> ID = 5
  fiveIdx = find(allIDs==5,1);
  fseek(h, locs(fiveIdx).start,'bof');
  sensors = struct();
  nrSensors =  fread(h, 1, 'uint16');
  for i = 1:nrSensors
    sensors(i).type = fread(h,1,'uint16');
    
    switch sensors(i).type
      case 1
        sensors(i).name = fread(h, 8, '*char')'; %8
        sensors(i).unknown1 = fread(h, 4, 'uint16');% 16
        sensors(i).azimuth = fread(h,1,'single'); %20
        sensors(i).longitude = fread(h,1,'single'); %24
        sensors(i).unknown3 = fread(h,76,'uint16'); %72
        sensors(i).unknown2 = fread(h,49,'uint16'); % %280
      case 8
        sensors(i).name = fread(h, 8, '*char')'; %8
        sensors(i).unknown1 = fread(h, 1, 'uint16'); %10
        sensors(i).comment = fread(h, 146, '*char')'; %156
        sensors(i).unknown3 = fread(h,10,'uint16');
        sensors(i).unknown2 = fread(h,49,'uint16'); % 280  
      case {4 7 5 6 3}
        sensors(i).name = fread(h, 8, '*char')'; %8
        sensors(i).unknown1 = fread(h, 1, 'uint16'); %10
        sensors(i).label = fread(h, 20, '*char')';
        sensors(i).comment = fread(h, 126, '*char')'; %156
        sensors(i).unknown3 = fread(h,10,'uint16');
        sensors(i).unknown2 = fread(h,49,'uint16'); % 280
      otherwise 
        error('Unknown sensor type');
    end
      

  end
  
  hdr.sensors = sensors;
  
  
  % Get Montage Info ---> ID = 3
  threeIdx = find(allIDs==3,1);
  fseek(h, locs(threeIdx).start,'bof');
  montageInfo = struct();
  montageInfo.name = fread(h, 32, '*char')'; 
  unknown6 = fread(h, 1, 'uint16'); 
  nrCh = fread(h, 1, 'uint16');
  montageInfo.ch = struct();
  for i = 1:nrCh
    montageInfo.ch(i).name = fread(h, 12, '*char')';
    montageInfo.ch(i).misc1 = fread(h,5,'single');
    montageInfo.ch(i).color = fread(h, 3, 'uint8');
    fseek(h,1,'cof');
    montageInfo.ch(i).misc2 = fread(h,3,'uint16');
    montageInfo.ch(i).conv = fread(h,1,'single');
  end
  
  hdr.montage = montageInfo;
  
  % Get Annotations ---> ID = 4
  fourIdx = find(allIDs==4,1);
  annStart = locs(fourIdx).start;
  allSecIds = [sections.id];
  foursecIdx = find(allSecIds==4,1);
  
  fseek(h, annStart,'bof');
  
  annotations = struct(...
    'startTime',[],...
    'startDate',[],...
    'endTime',[],...
    'endDate',[],...
    'comment',[]);
  
  for i = 1: sections(foursecIdx).rec
    annotations(i).type = fread(h,1,'uint16');  
    switch annotations(i).type
      case 1 % Global start and stop time
        annotations(i).misc1 = fread(h,2,'uint16');
        annotations(i).start = fread(h, 6, 'uint16');
        annotations(i).subsessionNr = fread(h, 1, 'uint16');
        annotations(i).sessionNr = fread(h, 1, 'uint16');
        
        aux = fread(h,1,'uint32');
        if aux == 1
          annotations(i).hasEnd = false;
          annotations(i).misc2 = fread(h,2,'uint16');
          annotations(i).nrTraces = fread(h,1,'uint16');
          annotations(i).samplingRate = fread(h,1,'uint16');
          fseek(h, 12,'cof');
        else
          annotations(i).hasEnd = true;
          annotations(i).misc2 = fread(h,2,'uint16');          
          annotations(i).nrTraces = fread(h,1,'uint16');
          annotations(i).samplingRate = fread(h,1,'uint16');
          annotations(i).stop = fread(h,6,'uint16');
        end

        annotations(i).misc3 = reshape(fread(h,120,'uint16'),10,[]);
        annotations(i).misc4 = fread(h,3,'uint16');

      case 2 % End Of File
        annotations(i).misc2 = fread(h,2,'uint16');
        annotations(i).stop = fread(h,6,'uint16');
        annotations(i).misc3 = fread(h,6,'uint16');
        annotations(i).nrTraces = fread(h,1,'uint16');
        annotations(i).samplingRate = fread(h,1,'uint16');
        
      case 3 % Standard Annotation
        annotations(i).misc1 = fread(h, 1, 'uint16');
        annotations(i).annIdx = fread(h, 1, 'uint16');
        annotations(i).startTime = fread(h, 3, 'uint16')';
        annotations(i).startTime = annotations(i).startTime(end:-1:1);
        annotations(i).startDate = fread(h, 3, 'uint16')';
        annotations(i).subsessionNr = fread(h, 1, 'uint16');
        annotations(i).sessionNr = fread(h, 1, 'uint16');
        
        aux = fread(h,1,'uint16');
        if aux == 1
          annotations(i).hasEnd = false;
        else
          annotations(i).hasEnd = true;
        end
        
        annotations(i).group = fread(h, 3, 'uint16');
        annotations(i).comment = fread(h, 42, '*char')';
        annotations(i).misc3 = reshape(fread(h, 64,'uint16'),8,[]);
        annotations(i).loc = fread(h,20,'*char');
        annotations(i).misc4 = fread(h,36,'uint16');
      otherwise
        display('Unknown annotation');
    end

  end
  
  hdr.annotations = annotations;
  hdr.unknown = [unknown1; unknown2; unknown3; unknown4; unknown5; unknown6];

  % Find Data --> Max ID number
  [~, dataIdx] = max([locs.id]);
  dataStart  = locs(dataIdx).start;
  
  hdr.nrValues = locs(dataIdx).length./(2*hdr.nrTraces);
  assert(mod(hdr.nrValues,1)==0,'Incorrect dataLength');
  
  if returnData


    fseek(h, dataStart,'bof');

    startOffset = (startIndex-1) * hdr.nrTraces * BYTESPERVALUE;
    if startOffset > 0
      fseek(h, startOffset, 'cof');
    end

    data = fread(h, lData*hdr.nrTraces,'*int16');
    data = reshape(data, hdr.nrTraces, [])';
    data = data(:,channels);

    % Multiply by conversion factor to get uV
    for iChan = 1 : length(channels)
      data(:,iChan) =  data(:,iChan) * hdr.chanInfo(channels(iChan)).conv;
    end
  end
  
  fclose(h);

end