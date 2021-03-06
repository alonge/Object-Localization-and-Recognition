function recall = boxesEval( varargin )
% Perform object proposal bounding box evaluation and plot results.
%
% boxesEval evaluates a set bounding box object proposals on the dataset
% specified by the 'data' parameter (which is generated by boxesData.m).
% The methods are specified by the vector 'names'. For each method the
% boxes must be stored in the file [resDir '/' name '-' data.split]. Each
% file should contain a single cell array 'bbs' of length n, with one set
% of bbs per image, where each matrix row has the format [x y w h score].
% Here score is the confidence of detection but if the boxes are sorted the
% score may be the same for every box. edgeBoxes.m stores results in this
% format by default, other methods can easily be converted to this format.
%
% For every method, evaluation is performed at every threshold in 'thrs'
% and every proposal count in 'cnts'. Two plots may be generated. If
% |cnts|>1 creates a plot with count on x-axis (and plots a separate set of
% curves for each threshold if necessary). If |thrs|>1 creates a plot with
% thresholds on x-axis (and plots a separate set of curves for each count).
%
% USAGE
%  recall = boxesEval( opts )
%
% INPUTS
%  opts       - parameters (struct or name/value pairs)
%   .data       - ['REQ'] data on which to evaluate (see boxesData.m)
%   .names      - ['REQ'] string cell array of object proposal methods
%   .resDir     - ['boxes/'] location for results and evaluation
%   .thrs       - [.7] IoU threshold(s) to use for evaluation
%   .cnts       - [...] propsal count(s) to use for evaluation
%   .maxn       - [inf] maximum number of images to use for evaluation
%   .show       - [1] figure for plotting results
%   .fName      - [''] optional filename for saving plots/recall to disk
%   .col        - [...] color(s) for plotting each method's results
%
% OUTPUTS
%  recall     - [MxTxK] recall for each count/threshold/method
%
% EXAMPLE
%
% See also edgeBoxesDemo, edgeBoxes, boxesData, bbGt
%
% Structured Edge Detection Toolbox      Version 3.01
% Code written by Piotr Dollar and Larry Zitnick, 2014.
% Licensed under the MSR-LA Full Rights License [see license.txt]

cnts=[1 2 5 10 20 50 100 200 500 1000 2000 5000]; col=cell(100,1);
for i=1:100, col{i}=max(.3,mod([.3 .47 .16]*(i+1),1)); end
dfs={ 'data','REQ', 'names','REQ', 'resDir','boxes/', 'thrs',.7, ...
  'cnts',cnts, 'maxn',inf, 'show',1, 'fName','', 'col',col };
o=getPrmDflt(varargin,dfs,1); if(~iscell(o.names)), o.names={o.names}; end
recall=boxesEvalAll(o); if(o.show), plotResult(recall,o); end

end

function recall = boxesEvalAll( o )
% compute and gather all results (caches individual results to disk)
M=length(o.cnts); T=length(o.thrs); K=length(o.names);
gt=o.data.gt; n=min(o.maxn,o.data.n); gt=gt(1:n);
recall=zeros(M,T,K); [ms,ts,ks]=ndgrid(1:M,1:T,1:K);
parfor i=1:M*T*K, m=ms(i); t=ts(i); k=ks(i);
  % if evaluation result exists simply load it
  rdir=[o.resDir '/eval/' o.names{k} '/' o.data.split '/'];
  rnm=[rdir 'N' int2str2(n,5) '-W' int2str2(o.cnts(m),5) ...
    '-T' int2str2(round(o.thrs(t)*100),2) '.txt']; %#ok<*PFBNS>
  if(exist(rnm,'file')), recall(i)=load(rnm,'-ascii'); continue; end
  % perform evaluation if result does not exist
  bbs=load([o.resDir '/' o.names{k} '-' o.data.split]); bbs=bbs.bbs;
  bbs1=bbs(1:n); for j=1:n, bbs1{j}=bbs1{j}(1:min(end,o.cnts(m)),:); end
  [gt1,bbs1]=bbGt('evalRes',gt,bbs1,o.thrs(t));
  [~,r]=bbGt('compRoc',gt1,bbs1,1); r=max(r); recall(i)=r;
  if(~exist(rdir,'dir')), mkdir(rdir); end; dlmwrite(rnm,r);
end
% display summary statistics
[ts,ks]=ndgrid(1:T,1:K); ms=log(o.cnts); rt=.75;
for i=1:T*K, t=ts(i); k=ks(i); r=recall(:,t,k)'; if(M==1), continue; end
  a=find(rt<=r); if(isempty(a)), m=inf; else a=a(1); b=a-1;
    m=round(exp((rt-r(b))/(r(a)-r(b))*(ms(a)-ms(b))+ms(b))); end
  auc=sum(diff(ms/ms(end)).*(r(1:end-1)+r(2:end))/2);
  fprintf('%15s  T=%.2f  A=%.2f  M=%4i  R=%.2f\n',...
    o.names{k},o.thrs(t),auc,m,max(r));
end
% optionally save results to text file
if(isempty(o.fName)), return; end
d=[o.resDir '/plots/']; if(~exist(d,'dir')), mkdir(d); end
dlmwrite([d o.fName '-' o.data.split '.txt'],squeeze(recall));
end

function plotResult( recall, o )
% plot results
[M,T,K]=size(recall); fSiz={'FontSize',12}; f=o.show;
for type=1:2
  if(type==1), xs=o.cnts; else xs=o.thrs; end;
  if(length(xs)==1), continue; end; s=[T,M]; M=s(type);
  R=recall; if(type==2), R=permute(R,[2 1 3]); end
  figure(f); f=f+1; clf; hold on; hs=zeros(M,K);
  for i=1:M, for k=1:K, hs(i,k)=plot(xs,R(:,i,k),...
        'Color',o.col{k},'LineWidth',3); end; end
  s={'# of proposals','IoU'}; xlabel(s{type},fSiz{:});
  s={'log','linear'}; set(gca,'XScale',s{type});
  ylabel('Detection Rate',fSiz{:}); set(gca,'YTick',0:.2:1);
  hold off; axis([min(xs) max(xs) 0 1]); grid on; set(gca,fSiz{:});
  set(gca,'XMinorGrid','off','XMinorTic','off');
  set(gca,'YMinorGrid','off','YMinorTic','off');
  s={'nw','ne'}; legend(hs(1,:),o.names,'Location',s{type});
  if(isempty(o.fName)), continue; end; s={'Cnt','IoU'};
  savefig([o.resDir '/plots/' s{type} '-' o.data.split '-' o.fName],'png');
end
end
