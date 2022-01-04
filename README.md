<p align="center"><img src="assets/puredns-logo.png" width="500"></p>

<p align="center">
    Fast domain resolver and subdomain bruteforcing with accurate wildcard filtering
    <br />
    <br />
    <a href="#usage">Usage</a>
    ·
    <a href="#how-it-works">How it works</a>
    ·
    <a href="#faq">FAQ</a>
</p>

# About

###### >>> Forked from https://github.com/d3mondev/puredns because they [do not wish to support a dockerised app](https://github.com/d3mondev/puredns/pull/20#issuecomment-919667417). If they change their mind, I will probably delete this repo.

**puredns** is a fast domain resolver and subdomain bruteforcing tool that can accurately filter out wildcard subdomains and DNS poisoned entries.

It uses [massdns](https://github.com/blechschmidt/massdns), a powerful stub DNS resolver, to perform bulk lookups. With the proper bandwidth and a good list of public resolvers, it can resolve millions of queries in just a few minutes. Unfortunately, the results from massdns are only as good as the answers provided by the public resolvers. The results are often polluted by wrong DNS answers and false positives from wildcard subdomains.

**puredns** solves this with its wildcard detection algorithm. It can filter out wildcards based on the DNS answers obtained from a set of trusted resolvers. It also attempts to work around DNS poisoning by validating the answers obtained using those trusted resolvers.

Think this is useful? :star: Star us on GitHub — it helps!

![puredns terminal](assets/puredns-terminal.png)

## Features

* Resolve thousands of DNS queries per second using massdns and a list of public DNS resolvers
* Bruteforce subdomains using a wordlist and a root domain
* Clean wildcards and detect wildcard roots using the minimal number of queries to ensure precise results
* Circumvent DNS load-balancing during wildcard detection
* Validate that the results are free of DNS poisoning by running against a list of known, trusted resolvers
* Save a list of valid domains, wildcard subdomain roots, and a clean massdns output containing only the valid entries
* Read a list of domains or words from stdin and enable quiet mode for easy integration into custom automation pipelines


# Usage

### Installation

#### From Docker Hub
```bash
❯ docker pull frost19k/puredns
```

#### Build it yourself
```bash
❯ git clone -b puredns https://github.com/frost19k/Dockerfiles.git ./puredns
❯ cd puredns
❯ docker buildx build -t puredns -f Dockerfile .
```

### Subdomain bruteforcing

Here's how to bruteforce a massive list of subdomains using a wordlist named `all.txt`:
```bash
❯ docker run -t --rm \
  -v "${PWD}/all.txt":"/puredns/all.txt" \
  frost19k/puredns bruteforce all.txt domain.com
```

### Resolving a list of domains

You can also resolve a list of domains contained in a text file (one per line).
```bash
❯ docker run -t --rm \
  -v "${PWD}/domains.txt":"/puredns/domains.txt" \
  frost19k/puredns resolve domains.txt
```

### Saving the results to files

You can save the following information to files to reuse it in your workflows:

* **domains**: clean list of domains that resolve correctly
* **wildcard root domains**: list of the wildcard root domains found (i.e., *\*.store.yahoo.com*)
* **massdns results file (-o Snl text output)**: can be used as a reference and to extract A and CNAME records.

```bash
❯ docker run -t --rm \
  -v "${PWD}/domains.txt":"/puredns/domains.txt" \
  -v "${PWD}/results":"/puredns/results" \
  frost19k/puredns resolve domains.txt \
  --write results/valid_domains.txt \
  --write-wildcards results/wildcards.txt \
  --write-massdns results/massdns.txt
```

# How it works

![puredns in operation](/assets/puredns-operation.gif)

You can see puredns in action against the domain google.com using a small wordlist of the 100k most common subdomains in the image above.

As part of its workflow, puredns performs three steps automatically:

1. Mass resolve using public DNS servers
2. Wildcard detection
3. Validation

#### 1. Mass resolve using public DNS servers

Using massdns, puredns will perform a mass resolve of all the domains and subdomains. It feeds the data to massdns through stdin, which allows it to throttle the number of queries per second if needed and perform basic sanitization on the list of domains generated.

By default, the input domains are set to lowercase, and only entries containing valid characters are accepted (essentially `[a-z0-9.-]`). You can disable this with the `--skip-sanitize` flag.

After this step, the results are usually polluted: some public resolvers will send back bad answers, and wildcard subdomains can quickly inflate the results.

#### 2. Wildcard detection

Puredns then uses its wildcard detection algorithm to detect and extract all the wildcard subdomain roots from the massdns results file.

It will use the massdns output from step 1 as a DNS cache to minimize the number of queries it needs to perform. To ensure precise results, it may have to validate the cache results by performing a DNS query.

You can skip this step using the `--skip-wildcard` flag.

#### 3. Validation

To protect against DNS poisoning, puredns uses massdns one last time to validate the remaining results using an internal list of trusted DNS resolvers. Currently, the trusted resolvers used are `8.8.8.8` and `8.8.4.4`. This step is done at a slower pace to avoid hitting any rate limiting on the trusted resolvers.

You can skip this step using the `--skip-validation` flag.

At this point, the resulting files should be clean of wildcard subdomains and DNS poisoned answers.

# FAQ

### How do I get resolvers for use with puredns?

The best way to obtain a list of public resolvers is to get one from [public-dns.info](https://public-dns.info/nameservers-all.txt), then use the [DNS Validator](https://github.com/vortexau/dnsvalidator) project to keep only resolvers that provide valid answers.

If your public resolvers provide incorrect information to puredns, for example by sending back poisoned replies, some subdomains can be missed as they will get filtered out. ***Hint:*** *Avoid resolvers from countries that censor the internet, like China.*

Once you have a list of custom resolvers, you can pass them to puredns with the `-r` argument:

`puredns resolve domains.txt -r resolvers.txt`

The default trusted resolvers are currently `8.8.8.8` and `8.8.4.4`. They don't need to be changed. If you do want to change them, you can also specify a custom list with the `--resolvers-trusted` argument. I have done many tests to find the best possible trusted resolvers for puredns - make sure to validate your results carefully if you decide to change them, and adjust the rate-limit with `--rate-limit-trusted`.

`puredns resolve domains.txt -r resolvers.txt --resolvers-trusted trusted.txt`

### Why are there domains that do not resolve to an IP address in the results?

Puredns does not simply ignore DNS answers containing NXDOMAIN. Sometimes, those NXDOMAIN answers have valid CNAME records that point to expired domains. If those records are present, they may point to an unregistered domain, allowing for subdomain takeovers.

If you are getting back domains that do not resolve to an IP address, check to see if they contain a CNAME record of interest:

`dig @8.8.8.8 CNAME example.com`

### Why are there wildcards not being filtered out correctly for some domains?

The most likely cause is DNS load balancing - sometimes, you'll get different IP addresses for each unique DNS query made. It can make it very hard to detect wildcard subdomains by comparing their DNS records.

You can specify the number of tests that puredns will perform to gather all the different IP addresses for a subdomain during wildcard detection. The default number is 3 tests, which is very low. I've seen domains with a lot of balancing take more than 50 queries to return results that were not perfect but good enough.

You can try to increase the number of tests performed to detect wildcard subdomains with the `--wildcard-tests` argument:

`puredns resolve domains.txt --wildcard-tests 50`

### Why does puredns crash with an out-of-memory error when resolving very large lists?

To detect wildcards, puredns needs to keep a cache of the DNS answers found. If your list of domains is in the hundreds of millions and contains many wildcard subdomains, the host can run out of memory. But there's an easy solution.

By default, puredns puts all the domains in a single batch to save on the number of DNS queries and execution time. If memory is a concern, it's possible to process the domains in multiple smaller batches with the `--wildcard-batch` argument. I have found a good size to be between 1M and 2M subdomains for a VPS with 1GB RAM.

`puredns resolve domains.txt --wildcard-batch 1000000`

### Why do the results sometimes contain duplicate domains?

Puredns does not remove duplicates anywhere in its pipeline. If the input file contains duplicate items such as identical words or domains, puredns will output duplicate elements. You can ensure that the input files provided to puredns are free of duplicates by using a tool like `sort -u`.

### I really enjoyed the old bash/python script. How can I get puredns v1.0 back?

Puredns v1.0 is still available in git but it is no longer maintained. If you still want it, you can use the following command to obtain the latest tagged version:

`git clone --branch v1.0.3 https://github.com/d3mondev/puredns`

# Resources

[public-dns.info](https://public-dns.info/) continuously updates a list of public and free DNS resolvers.

[DNS Validator](https://github.com/vortexau/dnsvalidator) can be used to curate your own list of public DNS resolvers.

[all.txt wordlist](https://gist.github.com/jhaddix/f64c97d0863a78454e44c2f7119c2a6a) Jhaddix's iconic `all.txt` wordlist is commonly used for subdomain enumeration.

[shuffleDNS](https://github.com/projectdiscovery/shuffledns) is a good alternative written in go that handles wildcard subdomains using a different algorithm.

# Disclaimer & License

Any resolvers included in this repository are present for reference only. The author is not responsible for any misuse of the resolvers in that list. It is the user's responsibility to curate a list of resolvers you are authorized to use.

Usage of this program for attacking targets without consent is illegal. It is the user's responsibility to obey all applicable laws. The developer assumes no liability and is not responsible for any misuse or damage caused by this program. Please use responsibly.

The material contained in this repository is licensed under GNU GPLv3.
