DOCKER = system("which podman") ? "podman" : "docker"
ENV.fetch("AWS_ACCOUNT_ID") { raise ArgumentError, "Please specify AWS_ACCOUNT_ID env" }

namespace :build do
  namespace :base do
    desc "Build base nginx image"
    task :nginx do
      sh "#{DOCKER} build --tag cndf2023-nginx-base:latest --file containerfiles/nginx/Containerfile ."
    end

    desc "Build base h2o image"
    task :h2o do
      sh "#{DOCKER} build --tag cndf2023-h2o-base:latest --file containerfiles/h2o/Containerfile ."
    end
  end
  namespace :aws_cloudfront_fargate  do
    desc "Build nginx image for CloudFront and Fargate"
    task nginx: ["base:nginx"] do
      sh "#{DOCKER} build --tag cndf2023-cloudfront-fargate-nginx:latest --file tf/aws_cloudfront_fargate/nginx/Containerfile ."
      sh "#{DOCKER} tag cndf2023-cloudfront-fargate-nginx:latest #{ENV["AWS_ACCOUNT_ID"]}.dkr.ecr.ap-northeast-1.amazonaws.com/cndf2023-cloudfront-fargate-nginx:latest"
    end

    desc "Build h2o image for CloudFront and Fargate"
    task h2o: ["base:h2o"] do
      sh "#{DOCKER} build --tag cndf2023-cloudfront-fargate-h2o:latest --file tf/aws_cloudfront_fargate/h2o/Containerfile ."
      sh "#{DOCKER} tag cndf2023-cloudfront-fargate-h2o:latest #{ENV["AWS_ACCOUNT_ID"]}.dkr.ecr.ap-northeast-1.amazonaws.com/cndf2023-cloudfront-fargate-h2o:latest"
    end
  end
  namespace :aws_nlb_fargate  do
    desc "Build nginx image for Network Load Balancer and Fargate"
    task nginx: ["base:nginx"] do
      sh "#{DOCKER} build --tag cndf2023-nlb-fargate-nginx:latest --file tf/aws_nlb_fargate/nginx/Containerfile ."
      sh "#{DOCKER} tag cndf2023-nlb-fargate-nginx:latest #{ENV["AWS_ACCOUNT_ID"]}.dkr.ecr.ap-northeast-1.amazonaws.com/cndf2023-nlb-fargate-nginx:latest"
    end

    desc "Build h2o image for Network Load Balancer and Fargate"
    task h2o: ["base:h2o"] do
      sh "#{DOCKER} build --tag cndf2023-nlb-fargate-h2o:latest --file tf/aws_nlb_fargate/h2o/Containerfile ."
      sh "#{DOCKER} tag cndf2023-nlb-fargate-h2o:latest #{ENV["AWS_ACCOUNT_ID"]}.dkr.ecr.ap-northeast-1.amazonaws.com/cndf2023-nlb-fargate-h2o:latest"
    end
  end
  namespace :gcp_lb_cloudrun do
    desc "Build nginx image for Cloud Load Balancing and Cloud Run"
    task nginx: ["base:nginx"] do
      sh "#{DOCKER} build --tag asia-northeast1-docker.pkg.dev/cndf2023-http3/cndf2023-lb-cloudrun/nginx:latest --file tf/gcp_load_balancing_cloudrun/nginx/Containerfile ."
    end

    desc "Build h2o image for Cloud Load Balancing and Cloud Run"
    task h2o: ["base:h2o"] do
      sh "#{DOCKER} build --tag asia-northeast1-docker.pkg.dev/cndf2023-http3/cndf2023-lb-cloudrun/h2o:latest --file tf/gcp_load_balancing_cloudrun/h2o/Containerfile ."
    end
  end
end

namespace :push do
  namespace :aws_cloudfront_fargate  do
    desc "Push nginx image for CloudFront and Fargate to ECR"
    task nginx: ["build:aws_cloudfront_fargate:nginx"] do
      sh "aws ecr get-login-password --region ap-northeast-1 | #{DOCKER} login --username AWS --password-stdin #{ENV["AWS_ACCOUNT_ID"]}.dkr.ecr.ap-northeast-1.amazonaws.com"
      sh "#{DOCKER} push #{ENV["AWS_ACCOUNT_ID"]}.dkr.ecr.ap-northeast-1.amazonaws.com/cndf2023-cloudfront-fargate-nginx:latest"
    end

    desc "Push h2o image for CloudFront and Fargate to ECR"
    task h2o: ["build:aws_cloudfront_fargate:h2o"] do
      sh "aws ecr get-login-password --region ap-northeast-1 | #{DOCKER} login --username AWS --password-stdin #{ENV["AWS_ACCOUNT_ID"]}.dkr.ecr.ap-northeast-1.amazonaws.com"
      sh "#{DOCKER} push #{ENV["AWS_ACCOUNT_ID"]}.dkr.ecr.ap-northeast-1.amazonaws.com/cndf2023-cloudfront-fargate-h2o:latest"
    end
  end
  namespace :aws_nlb_fargate  do
    desc "Push nginx image for Network Load Balancer and Fargate"
    task nginx: ["build:aws_nlb_fargate:nginx"] do
      sh "aws ecr get-login-password --region ap-northeast-1 | #{DOCKER} login --username AWS --password-stdin #{ENV["AWS_ACCOUNT_ID"]}.dkr.ecr.ap-northeast-1.amazonaws.com"
      sh "#{DOCKER} push #{ENV["AWS_ACCOUNT_ID"]}.dkr.ecr.ap-northeast-1.amazonaws.com/cndf2023-nlb-fargate-nginx:latest"
    end

    desc "Push h2o image for Network Load Balancer and Fargate"
    task h2o: ["build:aws_nlb_fargate:h2o"] do
      sh "aws ecr get-login-password --region ap-northeast-1 | #{DOCKER} login --username AWS --password-stdin #{ENV["AWS_ACCOUNT_ID"]}.dkr.ecr.ap-northeast-1.amazonaws.com"
      sh "#{DOCKER} push #{ENV["AWS_ACCOUNT_ID"]}.dkr.ecr.ap-northeast-1.amazonaws.com/cndf2023-nlb-fargate-h2o:latest"
    end
  end
  namespace :gcp_lb_cloudrun do
    desc "Push nginx image for Cloud Load Balancing and Cloud Run"
    task nginx: ["build:gcp_lb_cloudrun:nginx"] do
      sh "gcloud auth configure-docker asia-northeast1-docker.pkg.dev"
      sh "#{DOCKER} push asia-northeast1-docker.pkg.dev/cndf2023-http3/cndf2023-lb-cloudrun/nginx:latest"
    end

    desc "Push h2o image for Cloud Load Balancing and Cloud Run"
    task h2o: ["build:gcp_lb_cloudrun:h2o"] do
      sh "gcloud auth configure-docker asia-northeast1-docker.pkg.dev"
      sh "#{DOCKER} push asia-northeast1-docker.pkg.dev/cndf2023-http3/cndf2023-lb-cloudrun/h2o:latest"
    end
  end
end
